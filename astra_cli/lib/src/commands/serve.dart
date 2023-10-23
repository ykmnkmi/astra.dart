// ignore_for_file: avoid_print

import 'dart:async' show Completer, Future, Timer;
import 'dart:convert' show json, utf8;
import 'dart:io'
    show
        Directory,
        File,
        Platform,
        Process,
        ProcessSignal,
        Stdin,
        stderr,
        stdin,
        stdout;
import 'dart:math';

import 'package:astra/serve.dart' show ServerType;
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/extension.dart';
import 'package:astra_cli/src/version.dart';
import 'package:async/async.dart' show StreamGroup;
import 'package:path/path.dart' show absolute, join, normalize;
import 'package:vm_service/vm_service.dart'
    show Event, EventStreams, IsolateRef, VmService;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

const String _astraClose = 'ext.astra.close';

bool isCloseExtensionAdded(Event event) {
  return event.extensionRPC == _astraClose;
}

class ServeCommand extends CliCommand {
  ServeCommand()
      : name = 'serve',
        description = 'Serve Astra/Shelf application.',
        invocation = 'astra serve [options]',
        usageFooter = '',
        takesArguments = false {
    argParser
      // server
      ..addSeparator('Server options:')
      ..addOption('address',
          abbr: 'a',
          help: 'Bind server to this address.\n'
              'Bind will perform a InternetAddress.lookup and use the '
              'first value in the list.',
          valueHelp: 'localhost')
      ..addOption('port',
          abbr: 'p',
          help: 'Bind server to this port.\n'
              'If port has the value 0 an ephemeral port will be'
              ' chosen by the system.\nThe actual port used can be'
              ' retrieved using the port getter.',
          valueHelp: '8080')
      ..addOption('ssl-key', help: 'SSL key file.', valueHelp: 'file.key')
      ..addOption('ssl-cert',
          help: 'SSL certificate file.', valueHelp: 'file.crt')
      ..addOption('ssl-key-password',
          help: 'SSL keyfile password.', valueHelp: 'password')
      ..addOption('backlog',
          help: 'Number of connections to hold in backlog.\n'
              'If it has the value of 0 a reasonable value will'
              ' be chosen by the system.',
          valueHelp: '0')
      ..addFlag('v6Only',
          help: 'Restrict IP addresses to version 6 (IPv6) only.\n'
              'If an IP version 6 (IPv6) address is used, both IP'
              ' version 6 (IPv6) and version 4 (IPv4) connections will'
              ' be accepted.',
          negatable: false)
      ..addFlag('shared',
          help: 'Specifies whether additional servers can bind'
              ' to the same combination of address, port and v6Only.\n'
              "If it's true and more servers are bound to the port,"
              ' then the incoming connections will be distributed among'
              ' all the bound servers.',
          negatable: false)
      ..addOption('server-type',
          help: 'Server type.',
          valueHelp: ServerType.defaultType.name,
          allowed: ServerType.names,
          allowedHelp: ServerType.descriptions)
      ..addOption('isolates',
          abbr: 'i', help: 'Number of isolates.', valueHelp: '1')

      // debug
      ..addSeparator('Debugging options:')
      ..addFlag('debug', help: '', negatable: false)
      ..addFlag('hot-reload', help: '', negatable: false)
      ..addMultiOption('watch', abbr: 'w')
      ..addOption('service-port', valueHelp: '8181')
      ..addFlag('enable-asserts', negatable: false)
      ..addFlag('verbose',
          abbr: 'v', help: 'Print detailed logging.', negatable: false);
  }

  @override
  final String name;

  @override
  final String description;

  @override
  final String invocation;

  @override
  final String? usageFooter;

  @override
  final bool takesArguments;

  late final String address = getString('address') ?? 'localhost';

  late final int port = getInteger('port') ?? 8080;

  late final String? sslCert = getString('ssl-cert');

  late final String? sslKey = getString('ssl-key');

  late final String? sslKeyPass = getString('ssl-key-password');

  late final int backlog = getInteger('backlog') ?? 0;

  late final bool v6Only = getBoolean('v6Only') ?? false;

  late final bool shared = getBoolean('shared') ?? false;

  late final ServerType serverType = ServerType.values
      .byName(getString('server-type') ?? ServerType.defaultType.name);

  late final int isolates = getInteger('isolates') ?? 1;

  late final bool debug = getBoolean('debug') ?? false;

  late final bool hotReload = (getBoolean('hot-reload') ?? false) || debug;

  late final bool watch = watchList.isNotEmpty;

  late final List<String> watchList = getStringList('watch')
      .map<String>(normalize)
      .map<String>(absolute)
      .toList();

  late final int? servicePort = getInteger('service-port');

  late final bool enableAsserts = getBoolean('enable-asserts') ?? false;

  late final bool verbose = getBoolean('verbose') ?? false;

  late VmService service;

  late String isolateId;

  Future<String> createSource() async {
    var data = <String, String>{
      'VERSION': cliVersion,
      'PACKAGE': 'package:$package/$package.dart',
      'TARGET': target,
      'VERBOSE': '$verbose',
      'ADDRESS': "'$address'",
      'PORT': '$port',
      'BACKLOG': '$backlog',
      'V6ONLY': '$v6Only',
      'SHARED': '${shared || isolates > 1}',
      'SERVERTYPE': '$serverType',
      'ISOLATES': '$isolates',
      'HOTRELOAD': '$hotReload',
      'DEBUG': '$debug',
    };

    var sslKey = this.sslKey;
    var sslCert = this.sslCert;

    String serveTemplate;

    if (sslKey != null && sslCert != null) {
      serveTemplate = 'serveSecure';
      data['SSLKEY'] = "'${normalize(sslKey)}'";
      data['SSLCERT'] = "'${normalize(sslCert)}'";
      data['SSLKEYPASSWORD'] = sslKeyPass == null ? 'null' : "'$sslKeyPass'";
    } else {
      serveTemplate = 'serve';
    }

    data['SERVE'] = await renderTemplate('serve/_.$serveTemplate', data);
    return await renderTemplate('serve', data);
  }

  Future<void> reloadServer() async {
    if (hotReload) {
      await service.reloadSources(isolateId, force: true);
    } else {
      print('...');
    }
  }

  Future<void> restartServer() async {
    print('...');
  }

  Future<void> closeServer({bool force = false}) async {
    var args = <String, Object?>{'force': force};
    await service.callMethod(_astraClose, isolateId: isolateId, args: args);
  }

  void printServeModeUsage({bool hotReload = false}) {
    if (hotReload) {
      print("Press 'R' to restart and 'r' to reload.");
    } else {
      print("Press either 'R' or 'r' to restart.");
    }

    print("Press either 'C' or 'c' to graceful shutdown.");
    print("Press either 'Q' or 'q' to force quit.");
  }

  void clearScreen() {
    if (stdout.supportsAnsiEscapes) {
      stdout.write('\x1b[2J\x1b[H');
    } else if (Platform.isWindows) {
      // TODO(cli): windows: reset buffer
      print('Not supported yet.');
    } else {
      print('Not supported.');
    }
  }

  void killProcess(
    Process process, [
    ProcessSignal signal = ProcessSignal.sigterm,
  ]) {
    if (Platform.isWindows) {
      Process.run('taskkill', <String>['/F', '/T', '/PID', '${process.pid}']);
    } else {
      process.kill(signal);
    }
  }

  @override
  Future<void> check() async {
    await super.check();

    if (isolates < 1) {
      throw CliException("'isolates' must be greater than 0");
    }

    if (sslCert != null && sslKey == null) {
      // TODO(cli): update error message
      throw CliException('');
    }

    if (sslKey != null) {
      // TODO(cli): add warn message
    }
  }

  @override
  Future<int> handle() async {
    var source = await createSource();
    var scriptPath = join('.astra', 'serve-$cliVersion.dart');

    File(join(directory.path, scriptPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(source);

    var hash = (Random().nextInt(9000) + 1000).toRadixString(16);
    var serviceFileUri = Directory.systemTemp.uri
        .resolveUri(Uri.file('dart-vm-service-$hash.json'));
    var serviceInfoFile = File.fromUri(serviceFileUri);

    var arguments = <String>[
      servicePort == null
          ? '--enable-vm-service'
          : '--enable-vm-service=$servicePort',
      '--no-serve-devtools',
      '--no-warn-on-pause-with-no-debugger',
      '--write-service-info=$serviceFileUri'
    ];

    if (debug) {
      arguments.addAll(<String>[
        // '--serve-devtools',
        '--pause-isolates-on-exit',
        '--pause-isolates-on-unhandled-exceptions',
      ]);
    } else {
      arguments.addAll(<String>[
        '--no-pause-isolates-on-exit',
        '--no-pause-isolates-on-unhandled-exceptions',
      ]);
    }

    if (debug || enableAsserts) {
      arguments.add('--enable-asserts');
    }

    arguments
      ..add('-DSILENT_VM_SERVICE=true')
      ..addAll(<String>[for (var define in defineList) '-D$define'])
      ..add(scriptPath);

    var process = await Process.start(Platform.executable, arguments,
        workingDirectory: directory.path, runInShell: true);

    var stdoutSubscription = process.stdout.listen(stdout.add);
    var stderrSubscription = process.stderr.listen(stderr.add);

    var serviceInfoUriCompleter = Completer<Uri>();

    void poll(Timer timer) {
      try {
        if (serviceInfoFile.existsSync()) {
          var content = serviceInfoFile.readAsStringSync().trimRight();

          if (content.endsWith('}')) {
            var serviceInfo = json.decode(content);

            if (serviceInfo case {'uri': String uri}) {
              serviceInfoUriCompleter.complete(Uri.parse(uri));
              serviceInfoFile.deleteSync();
            } else {
              // TODO(serve): update exception
              serviceInfoUriCompleter.completeError(Exception());
            }

            timer.cancel();
          }
        }
      } finally {
        if (serviceInfoFile.existsSync()) {
          serviceInfoFile.deleteSync();
        }
      }
    }

    Timer.periodic(const Duration(milliseconds: 50), poll);

    var Uri(:host, :port, :path) = await serviceInfoUriCompleter.future;
    service = await vmServiceConnectUri('ws://$host:$port${path}ws');
    await service.streamListen(EventStreams.kIsolate);
    await service.onIsolateEvent.firstWhere(isCloseExtensionAdded);

    var group = StreamGroup<Object>()
      ..add(process.exitCode.asStream())
      ..add(ProcessSignal.sigint.watch())
      ..add(ProcessSignal.sigterm.watch())
      ..add(utf8.decoder.bind(stdin));

    var vm = await service.getVM();

    if (vm.isolates case [IsolateRef(id: var id?), ...]) {
      isolateId = id;
    } else {
      // TODO(serve): update exception
      throw Exception();
    }

    var Stdin(:echoMode, :lineMode) = stdin;

    stdin
      ..echoMode = false
      ..lineMode = false;

    void restoreInput() {
      stdin
        ..lineMode = lineMode
        ..echoMode = echoMode;
    }

    if (debug) {
      // TODO(serve): print DevTools links.
    }

    printServeModeUsage(hotReload: hotReload);

    var closed = false;

    await for (var event in group.stream) {
      if (event case int()) {
        restoreInput();
        break;
      } else if (event case ProcessSignal signal) {
        killProcess(process, signal);
        restoreInput();
        break;
      } else if (event case String key) {
        if (key case 'r' when !closed) {
          await reloadServer();
        } else if (key case 'R' when !closed) {
          await restartServer();
        } else if (key case 'c' || 'C') {
          if (closed) {
            restoreInput();
            killProcess(process);
            break;
          }

          print('Closing ...');
          await closeServer();

          if (debug) {
            print("Press either 'C' or 'c' to stop the Dart DevTools.");
            closed = true;
          } else {
            restoreInput();
            break;
          }
        } else if (key case 'q' || 'Q') {
          print('Force closing ...');
          await closeServer(force: true);
          restoreInput();
          killProcess(process);
          break;
        } else if (key case 'h' || 'H') {
          printServeModeUsage(hotReload: hotReload);
        } else if (key case 's' || 'S') {
          clearScreen();
        }
      }
    }

    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
    await service.dispose();
    return 0;
  }
}
