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
import 'package:vm_service/vm_service.dart' show Event, EventStreams, VmService;
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
      ..addOption(
        'address',
        abbr: 'a',
        help:
            'Bind server to this address.\n'
            'Bind will perform a InternetAddress.lookup and use the first '
            'value in the list.',
        valueHelp: 'localhost',
      )
      ..addOption(
        'port',
        abbr: 'p',
        help:
            'Bind server to this port.\n'
            'If port has the value 0 an ephemeral port will be  chosen by the '
            'system.',
        valueHelp: '8080',
      )
      ..addOption('ssl-key', help: 'SSL key file.', valueHelp: 'file.key')
      ..addOption(
        'ssl-cert',
        help: 'SSL certificate file.',
        valueHelp: 'file.crt',
      )
      ..addOption(
        'ssl-key-password',
        help: 'SSL keyfile password.',
        valueHelp: 'password',
      )
      ..addOption(
        'backlog',
        help:
            'Number of connections to hold in backlog.\n'
            'If backlog has the value of 0 (the default) a reasonable value '
            'will be chosen by the system.',
        valueHelp: '0',
      )
      ..addFlag(
        'v6Only',
        help:
            'Restrict IP addresses to version 6 (IPv6) only.\n'
            'If an IP version 6 (IPv6) address is used, both IP'
            ' version 6 (IPv6) and version 4 (IPv4) connections will'
            ' be accepted.',
        negatable: false,
      )
      ..addFlag(
        'shared',
        help:
            'Specifies whether additional servers can bind'
            ' to the same combination of address, port and v6Only.\n'
            "If it's true and more servers are bound to the port,"
            ' then the incoming connections will be distributed among'
            ' all the bound servers.',
        negatable: false,
      )
      ..addOption(
        'server-type',
        help: 'Server type.',
        valueHelp: ServerType.defaultType.name,
        allowed: ServerType.names,
        allowedHelp: ServerType.descriptions,
      )
      ..addOption(
        'isolates',
        abbr: 'i',
        help: 'Number of isolates.',
        valueHelp: '1',
      )
      // debug
      ..addSeparator('Debugging options:')
      ..addFlag('debug', help: '', negatable: false)
      ..addFlag('hot-reload', help: 'Enable hot-reload.', negatable: false)
      ..addMultiOption('watch', abbr: 'w')
      ..addOption('service-port', valueHelp: '8181')
      ..addFlag(
        'enable-asserts',
        negatable: false,
        help: 'Enable assert statements.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Print detailed logging.',
        negatable: false,
      );
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

  late final int port = getInteger('port', 0) ?? 8080;

  late final String? sslCert = getString('ssl-cert');

  late final String? sslKey = getString('ssl-key');

  late final String? sslKeyPass = getString('ssl-key-password');

  late final int backlog = getInteger('backlog', 0) ?? 0;

  late final bool v6Only = getBoolean('v6Only') ?? false;

  late final bool shared = getBoolean('shared') ?? false;

  late final ServerType serverType = ServerType.values.byName(
    getString('server-type') ?? ServerType.defaultType.name,
  );

  late final int isolates = getInteger('isolates', 0) ?? 0;

  late final bool debug = getBoolean('debug') ?? false;

  late final bool hotReload = (getBoolean('hot-reload') ?? false) || debug;

  late final bool watch = watchList.isNotEmpty;

  late final List<String> watchList = getStringList(
    'watch',
  ).map<String>(normalize).map<String>(absolute).toList();

  late final int? servicePort = getInteger('service-port', 0);

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
    }
  }

  Future<Process> restartServer(Process process) async {
    // TODO(cli): add restart message.
    print('...');
    return process;
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

    if (sslCert != null && sslKey == null) {
      usageException('');
    }

    if (sslKey != null) {
      // TODO(cli): add warning message.
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
    var fileUri = Uri.file('dart-vm-service-$hash.json');
    var serviceFileUri = Directory.systemTemp.uri.resolveUri(fileUri);
    var serviceInfoFile = File.fromUri(serviceFileUri);

    var arguments = <String>[
      servicePort == null
          ? '--enable-vm-service'
          : '--enable-vm-service=$servicePort',
      '--no-serve-devtools',
      '--no-warn-on-pause-with-no-debugger',
      '--write-service-info=$serviceFileUri',
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

    if (!debug) {
      arguments.add('-DSILENT_VM_SERVICE=true');
    }

    arguments
      ..addAll(<String>[for (var define in defineList) '-D$define'])
      ..add(scriptPath);

    var process = await Process.start(
      Platform.executable,
      arguments,
      workingDirectory: directory.path,
      runInShell: true,
    );

    var stdoutSubscription = process.stdout.listen(stdout.add);
    var stderrSubscription = process.stderr.listen(stderr.add);

    var serviceInfoUriCompleter = Completer<Uri>();

    void poll(Timer timer) {
      if (serviceInfoFile.existsSync()) {
        try {
          var content = serviceInfoFile.readAsStringSync().trimRight();

          if (content.endsWith('}')) {
            var serviceInfo = json.decode(content) as Map<String, Object>;
            var uri = serviceInfo['uri'];

            if (uri is String) {
              serviceInfoUriCompleter.complete(Uri.parse(uri));
              serviceInfoFile.deleteSync();
            } else {
              // TODO(cli): update exception message.
              serviceInfoUriCompleter.completeError(CliException(''));
            }

            timer.cancel();
          }
        } finally {
          if (serviceInfoFile.existsSync()) {
            serviceInfoFile.deleteSync();
          }
        }
      }
    }

    // TODO(cli): add poll timeout and option.
    Timer.periodic(const Duration(milliseconds: 100), poll);

    var serviceInfoUri = await serviceInfoUriCompleter.future;
    var host = serviceInfoUri.host;
    var path = serviceInfoUri.path;
    service = await vmServiceConnectUri('ws://$host:$port${path}ws');
    await service.streamListen(EventStreams.kIsolate);
    await service.onIsolateEvent.firstWhere(isCloseExtensionAdded);

    var group = StreamGroup<Object>()
      ..add(process.exitCode.asStream())
      ..add(ProcessSignal.sigint.watch())
      ..add(ProcessSignal.sigterm.watch())
      ..add(utf8.decoder.bind(stdin));

    var vm = await service.getVM();
    var isolates = vm.isolates;

    if (isolates == null || isolates.isEmpty) {
      throw StateError('');
    }

    isolateId = isolates.first.id!;

    var echoMode = stdin.echoMode;
    var lineMode = stdin.lineMode;

    stdin
      ..echoMode = false
      ..lineMode = false;

    void restoreInput() {
      stdin
        ..lineMode = lineMode
        ..echoMode = echoMode;
    }

    printServeModeUsage(hotReload: hotReload);

    var closed = false;

    await for (var event in group.stream) {
      if (event is int) {
        restoreInput();
        break;
      } else if (event is ProcessSignal) {
        killProcess(process, event);
        restoreInput();
        break;
      } else if (event is String) {
        if (event == 'r' && !closed) {
          await reloadServer();
        } else if (event == 'R' && !closed) {
          process = await restartServer(process);
        } else if (event == 'c' || event == 'C') {
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
        } else if (event == 'q' || event == 'Q') {
          print('Force closing ...');
          await closeServer(force: true);
          restoreInput();
          killProcess(process);
          break;
        } else if (event == 'h' || event == 'H') {
          printServeModeUsage(hotReload: hotReload);
        } else if (event == 's' || event == 'S') {
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
