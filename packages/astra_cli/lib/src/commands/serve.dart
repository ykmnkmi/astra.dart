import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:astra/serve.dart';
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/extension.dart';
import 'package:astra_cli/src/type.dart';
import 'package:astra_cli/src/version.dart';
import 'package:path/path.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

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

  Future<String> createSource(TargetType targetType) async {
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

    data['CREATE'] = await renderTemplate('serve/${targetType.name}', data);
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
    } else if (sslKey != null) {
      // TODO(cli): add warn message
    }
  }

  @override
  Future<int> handle() async {
    var includedPaths = <String>[directory.path];
    var collection = AnalysisContextCollection(includedPaths: includedPaths);
    var context = collection.contextFor(directory.absolute.path);
    var session = context.currentSession;
    var resolvedUnit = await session.getResolvedUnit(targetFile.absolute.path);

    if (resolvedUnit is! ResolvedUnitResult) {
      throw CliException('Library not resolved');
    }

    if (resolvedUnit.errors.isNotEmpty) {
      throw resolvedUnit.errors.first;
    }

    var memberType = TargetType.getFor(resolvedUnit, target: target);
    var source = await createSource(memberType);
    var scriptPath = join('.dart_tool', 'astra', 'serve-$cliVersion.dart');

    File(join(directory.path, scriptPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(source);

    var arguments = <String>[
      '-DSILENT_OBSERVATORY=true',
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

      void onExit(int code) {
        if (completer.isCompleted) {
          return;
        }

        // TODO(cli): update error
        completer.completeError('not started');
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
        completer.complete(string);
        stdoutSubscription.onData(stdout.add);
      }

      stdoutSubscription = process.stdout.listen(onMessage);
      process.stderr.listen(stderr.add);

      var config = await completer.future;
      var parts = config.split(',');

      var webSocketUri = parts[0];
      var main = parts[1];

      VmService service;

      try {
        service = await vmServiceConnectUri(webSocketUri);
      } catch (error, stackTrace) {
        stderr
          ..writeln(error)
          ..writeln(stackTrace);
        restoreStdinMode();
        exit(1);
      }

      late List<String> isolates;

      Future<void> startServer() async {
        try {
          var response = await service.callServiceExtension(
            'ext.astra.start',
            isolateId: main,
          );

          var list = response.json!['isolates'] as List<Object?>;
          isolates = list.cast<String>();
        } catch (error, stackTrace) {
          stderr
            ..writeln(error)
            ..writeln(stackTrace);
        }
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
              ..writeln(stackTrace);
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
          await service.callServiceExtension(
            'ext.astra.pause',
            isolateId: main,
          );

          await service.reloadSources(main);

          var response = await service.callServiceExtension(
            'ext.astra.resume',
            isolateId: main,
          );

          isolates = (response.json!['isolates'] as List).cast<String>();
        } catch (error, stackTrace) {
          stderr
            ..writeln(error)
            ..writeln(stackTrace);
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
            ..writeln(stackTrace);
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
            ..writeln(stackTrace);
        }
      }

      if (debug) {
        stdout.writeln('Debug service listening on $webSocketUri');
      }

      printServeModeUsage(hot: hot);

      await startServer();

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
            ..writeln(stackTrace);
        }
      }

      code = 0;
      await done;
    } catch (error, stackTrace) {
      stderr
        ..writeln(error)
        ..writeln(stackTrace);

      code = 1;
    }

    return code;
  }
}

void printServeModeUsage({bool detailed = false, bool hot = false}) {
  if (hot) {
    stdout.writeln("Press 'r' to hot-reload and 'R' to hot-restart.");
  } else {
    stdout.writeln("Press 'r' or 'R' to restart.");
  }

  stdout
    ..writeln("Press 'c' or 'C' to graceful shutdown.")
    ..writeln("Press 'q' or 'Q' to force quit.")
    ..writeln("Press 's' or 'S' to clear terminal.")
    ..writeln("Press 'h' or 'H' to show this help message.");
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
