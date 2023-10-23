import 'dart:async' show Completer, Future, StreamSubscription;
import 'dart:convert' show json;
import 'dart:io'
    show File, Platform, Process, StdinException, exit, stderr, stdin, stdout;

import 'package:astra/serve.dart' show ServerType;
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/extension.dart';
import 'package:astra_cli/src/version.dart';
import 'package:path/path.dart' show absolute, join, normalize;
import 'package:stack_trace/stack_trace.dart' show Trace;
import 'package:vm_service/vm_service.dart' show VmService;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

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
      ..addOption('server-type',
          help: 'Server type.',
          valueHelp: ServerType.defaultType.name,
          allowed: ServerType.names,
          allowedHelp: ServerType.descriptions)
      ..addOption('concurrency',
          abbr: 'j', help: 'Number of isolates.', valueHelp: '1')
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
      ..addOption('backlog',
          help: 'Number of connections to hold in backlog.\n'
              'If it has the value of 0 a reasonable value will'
              ' be chosen by the system.',
          valueHelp: '0')
      ..addFlag('shared',
          help: 'Specifies whether additional servers can bind'
              ' to the same combination of address, port and v6Only.\n'
              "If it's true and more servers are bound to the port,"
              ' then the incoming connections will be distributed among'
              ' all the bound servers.',
          negatable: false)
      ..addFlag('v6Only',
          help: 'Restrict IP addresses to version 6 (IPv6) only.\n'
              'If an IP version 6 (IPv6) address is used, both IP'
              ' version 6 (IPv6) and version 4 (IPv4) connections will'
              ' be accepted.',
          negatable: false)
      ..addOption('ssl-key', help: 'SSL key file.', valueHelp: 'file.key')
      ..addOption('ssl-cert',
          help: 'SSL certificate file.', valueHelp: 'file.crt')
      ..addOption('ssl-key-password',
          help: 'SSL keyfile password.', valueHelp: 'password')

      // debug
      ..addSeparator('Debugging options:')
      ..addFlag('debug', negatable: false)
      ..addFlag('hot', negatable: false)
      ..addMultiOption('watch', abbr: 'w')
      ..addOption('service-port', valueHelp: '8181')
      ..addFlag('enable-asserts', negatable: false);
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

  late final ServerType serverType = ServerType.values
      .byName(getString('server-type') ?? ServerType.defaultType.name);

  late final int concurrency = getInteger('concurrency') ?? 1;

  late final String address = getString('address') ?? 'localhost';

  late final int port = getInteger('port') ?? 8080;

  late final int backlog = getInteger('backlog') ?? 0;

  late final bool shared = getBoolean('shared') ?? false;

  late final bool v6Only = getBoolean('v6Only') ?? false;

  late final String? sslCert = getString('ssl-cert');

  late final String? sslKey = getString('ssl-key');

  late final String? sslKeyPass = getString('ssl-key-password');

  late final bool debug = getBoolean('debug') ?? false;

  late final bool hot = getBoolean('hot') ?? false;

  late final bool watch = watchList.isNotEmpty;

  late final List<String> watchList =
      getStringList('watch').map<String>(normalize).toList();

  late final int? servicePort = getInteger('service-port');

  late final bool enableAsserts = getBoolean('enable-asserts') ?? false;

  Future<String> createSource() async {
    var data = <String, String>{
      'VERSION': cliVersion,
      'PACKAGE': 'package:$package/$package.dart',
      'TARGET': target,
      'SERVERTYPE': '$serverType',
      'CONCURRENCY': '$concurrency',
      'VERBOSE': '$verbose',
      'ADDRESS': "'$address'",
      'PORT': '$port',
      'BACKLOG': '$backlog',
      'SHARED': '${shared || concurrency > 1}',
      'V6ONLY': '$v6Only',
    };

    var sslKey = this.sslKey;
    var sslCert = this.sslCert;
    String serveTemplate;

    if (sslKey != null && sslCert != null) {
      serveTemplate = 'serveSecure';
      data['SSLKEY'] = "'${absolute(sslKey)}'";
      data['SSLCERT'] = "'${absolute(sslCert)}'";
      data['SSLKEYPASSWORD'] = sslKeyPass == null ? 'null' : "'$sslKeyPass'";
    } else {
      serveTemplate = 'serve';
    }

    data['SERVE'] = await renderTemplate('serve/_.$serveTemplate', data);
    return await renderTemplate('serve', data);
  }

  @override
  Future<void> check() async {
    await super.check();

    if (concurrency < 1) {
      throw CliException("'concurrency' must be greater than 0");
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
    var scriptPath = join('.dart_tool', 'astra', 'serve-$cliVersion.dart');

    File(join(directory.path, scriptPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(source);

    var arguments = <String>[
      servicePort == null
          ? '--enable-vm-service'
          : '--enable-vm-service=$servicePort',
    ];

    if (debug) {
      arguments.addAll(<String>[
        '--serve-devtools',
        '--pause-isolates-on-exit',
        '--pause-isolates-on-unhandled-exceptions',
      ]);
    } else {
      arguments.addAll(<String>[
        '--no-serve-devtools',
        '--no-pause-isolates-on-exit',
        '--no-pause-isolates-on-unhandled-exceptions',
        '--no-warn-on-pause-with-no-debugger',
      ]);
    }

    if (enableAsserts) {
      arguments.add('--enable-asserts');
    }

    arguments
      ..addAll(<String>[for (var define in defineList) '-D$define'])
      ..add(scriptPath);

    var previousEchoMode = stdin.echoMode;
    var previousLineMode = stdin.lineMode;

    try {
      stdin
        ..echoMode = false
        ..lineMode = false;
    } on StdinException catch (error) {
      // TODO(cli): log error
      stderr.writeln(error);
    }

    void restoreStdinMode() {
      try {
        stdin
          ..lineMode = previousLineMode
          ..echoMode = previousEchoMode;
      } on StdinException catch (error) {
        // TODO(cli): log error
        stderr.writeln(error);
      }
    }

    int code;

    try {
      var completer = Completer<String>();
      var buffer = StringBuffer();

      void onExit(int code) {
        if (completer.isCompleted) {
          return;
        }

        // TODO(cli): update error
        completer.completeError(StateError('exit code: $code'));
      }

      var process = await Process.start(
        Platform.executable,
        arguments,
        workingDirectory: directory.path,
        runInShell: true,
      );

      var done = process.exitCode.then<void>(onExit);

      late StreamSubscription<List<int>> stdoutSubscription;

      void onMessage(List<int> bytes) {
        var string = String.fromCharCodes(bytes);

        if (RegExp('ws://127.0.0.1:\\d+/.*,isolates/\\d+').hasMatch(string)) {
          completer.complete(string);

          void onData(List<int> bytes) {
            buffer.write(String.fromCharCodes(bytes));
          }

          stdoutSubscription.onData(onData);
        } else {
          buffer.write(string);
        }
      }

      stdoutSubscription = process.stdout.listen(onMessage);
      process.stderr.listen(stderr.add);

      var config = await completer.future;
      var [webSocketUri, main, ...isolates] = config.trimRight().split(',');

      VmService service;

      try {
        service = await vmServiceConnectUri(webSocketUri);
      } catch (error, stackTrace) {
        stderr
          ..writeln(error)
          ..writeln(Trace.format(stackTrace));

        restoreStdinMode();
        exit(1);
      }

      Future<void> Function() reloadServer;

      if (hot) {
        Future<void> reloadIsolate(String isolate) async {
          await service.reloadSources(isolate);

          await service.callServiceExtension(
            'ext.astra.reload',
            isolateId: isolate,
          );
        }

        reloadServer = () async {
          try {
            var futures = isolates.map<Future<void>>(reloadIsolate);
            await Future.wait<void>(futures);
          } catch (error, stackTrace) {
            stderr
              ..writeln(error)
              ..writeln(Trace.format(stackTrace));
          }
        };
      } else {
        reloadServer = () async {
          stdout
            ..writeln('Hot-Reload not enabled.')
            ..writeln("Run with '--hot' option.");
        };
      }

      Future<void> restartServer() async {
        try {
          await service.reloadSources(main);

          var response = await service.callServiceExtension(
            'ext.astra.restart',
            isolateId: main,
          );

          isolates = (response.json!['isolates'] as List).cast<String>();
        } catch (error, stackTrace) {
          stderr
            ..writeln(error)
            ..writeln(Trace.format(stackTrace));
        }
      }

      Future<void> closeServer() async {
        try {
          await service.callServiceExtension(
            'ext.astra.close',
            isolateId: main,
          );
        } catch (error, stackTrace) {
          stderr
            ..writeln(error)
            ..writeln(Trace.format(stackTrace));
        }
      }

      Future<void> killServer() async {
        try {
          await service.callServiceExtension(
            'ext.astra.kill',
            isolateId: main,
          );
        } catch (error, stackTrace) {
          stderr
            ..writeln(error)
            ..writeln(Trace.format(stackTrace));
        }
      }

      if (debug) {
        stdout.writeln('Debug service listening on $webSocketUri');
      }

      printServeModeUsage(hot: hot);
      stdout.write(buffer);
      stdoutSubscription.onData(stdout.add);

      await for (var bytes in stdin) {
        try {
          var event = String.fromCharCodes(bytes);

          if (event == 'r') {
            await reloadServer();
          } else if (event == 'R') {
            await restartServer();
          } else if (event == 'c' || event == 'C') {
            stdout.writeln('Closing ...');
            await closeServer();
            restoreStdinMode();
            break;
          } else if (event == 'q' || event == 'Q') {
            stdout.writeln('Force closing ...');
            await killServer();
            restoreStdinMode();
            break;
          } else if (event == 's' || event == 'S') {
            clearScreen();
          } else if (event == 'h' || event == 'H') {
            printServeModeUsage(hot: hot);
          } else {
            stdout.writeln('Unknown key: ${json.encode(event)}');
          }
        } catch (error, stackTrace) {
          stderr
            ..writeln(error)
            ..writeln(Trace.format(stackTrace));
        }
      }

      code = 0;
      await done;
    } catch (error, stackTrace) {
      stderr
        ..writeln(error)
        ..writeln(Trace.format(stackTrace));

      code = 1;
    }

    return code;
  }
}

void printServeModeUsage({bool detailed = false, bool hot = false}) {
  if (hot) {
    stdout.writeln("Press 'r' to hot-reload and 'R' to hot-restart.");
  } else {
    stdout.writeln("Press 'r' or 'R' to hot-restart.");
  }

  stdout
    ..writeln("Press 'c' or 'C' to graceful shutdown.")
    ..writeln("Press 'q' or 'Q' to force quit.")
    ..writeln("Press 's' or 'S' to clear terminal.")
    ..writeln("Press 'h' or 'H' to show this help message.")
    ..writeln();
}

void clearScreen() {
  if (stdout.supportsAnsiEscapes) {
    stdout.write('\x1b[2J\x1b[H');
  } else if (Platform.isWindows) {
    // TODO(cli): windows: reset buffer
    stdout.writeln('Not supported yet.');
  } else {
    stdout.writeln('Not supported.');
  }
}