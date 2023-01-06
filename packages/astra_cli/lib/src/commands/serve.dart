import 'dart:async' show EventSink, Future, StreamTransformer;
import 'dart:convert' show LineSplitter, utf8;
import 'dart:io'
    show
        File,
        Platform,
        Process,
        ProcessSignal,
        StdinException,
        exit,
        stderr,
        stdin,
        stdout;

import 'package:analyzer/dart/analysis/analysis_context_collection.dart'
    show AnalysisContextCollection;
import 'package:analyzer/dart/analysis/results.dart' show ResolvedUnitResult;
import 'package:astra/serve.dart' show ServerType;
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/extension.dart';
import 'package:astra_cli/src/type.dart';
import 'package:astra_cli/src/version.dart';
import 'package:async/async.dart' show StreamGroup;
import 'package:path/path.dart' show absolute, join, normalize;
import 'package:vm_service/vm_service.dart'
    show Event, EventKind, ExtensionData;
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

  late final int servicePort = getInteger('service-port') ?? 8181;

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

    if ((sslKey == null) ^ (sslCert == null)) {
      // TODO(cli): update error message
      throw CliException("'ssl-key' ^ 'ssl-cert'");
    }
  }

  @override
  Future<int> handle() async {
    var includedPaths = <String>[packageDirectory.absolute.path];
    var collection = AnalysisContextCollection(includedPaths: includedPaths);
    var context = collection.contextFor(packageDirectory.absolute.path);
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
    File(join(packageDirectory.path, scriptPath))
      ..createSync(recursive: true)
      ..writeAsStringSync(source);

    var arguments = <String>[
      for (var define in defineList) '-D$define',
      '-DSILENT_OBSERVATORY=true',
      '--enable-vm-service=$servicePort',
      '--disable-service-auth-codes',
      '--no-serve-devtools',
    ];

    if (debug) {
      arguments += <String>[
        '--pause-isolates-on-exit',
        '--pause-isolates-on-unhandled-exceptions',
      ];
    } else if (hot) {
      arguments += <String>[
        '--no-pause-isolates-on-exit',
        '--no-pause-isolates-on-unhandled-exceptions',
        '--no-dds',
      ];
    }

    if (enableAsserts) {
      arguments.add('--enable-asserts');
    }

    arguments.add(scriptPath);

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

    var group = StreamGroup<Object?>()
      ..add(stdin.map<String>(String.fromCharCodes))
      ..add(ProcessSignal.sigint.watch());

    var buffer = StringBuffer();
    int code;

    try {
      var process = await Process.start(
        Platform.executable,
        arguments,
        workingDirectory: packageDirectory.path,
      );

      void messageMapper(String message, EventSink<String> sink) {
        var lines = const LineSplitter().convert(message);
        var first = lines.first;
        var buffer = StringBuffer('- $first');

        for (var line in lines.skip(1)) {
          buffer
            ..writeln()
            ..write('  $line');
        }

        sink.add(buffer.toString());
      }

      var messageTransformer = StreamTransformer<String, String>.fromHandlers(
        handleData: messageMapper,
      );

      var scrout = process.stdout
          .transform<String>(utf8.decoder)
          .transform<String>(messageTransformer)
          .listen(buffer.writeln);

      var screrr = process.stderr
          .transform<String>(utf8.decoder)
          .transform<String>(messageTransformer)
          .listen(buffer.writeln);

      var wsUri = 'ws://localhost:$servicePort/ws';
      var service = await vmServiceConnectUri(wsUri);
      await service.streamListen(EventKind.kExtension);

      List<String> isolateIDs;

      {
        var event = await service.onExtensionEvent.firstWhere(isStarted);
        var extensionData = event.extensionData;

        if (extensionData is! ExtensionData) {
          // TODO(cli): update error message
          throw CliException('no data');
        }

        var data = extensionData.data;

        if (!data.containsKey('isolateIDs')) {
          // TODO(cli): update error message
          throw CliException('no ids');
        }

        isolateIDs = List<String>.from(data['isolateIDs'] as List<Object?>);
      }

      Future<void> Function() reloadServer;
      Future<void> Function() restartServer;

      if (hot) {
        Future<void> reloadIsolate(String isolateId) async {
          await service.reloadSources(isolateId);

          await service.callServiceExtension(
            'ext.astra.reload',
            isolateId: isolateId,
          );
        }

        reloadServer = () async {
          var futures = isolateIDs.map<Future<void>>(reloadIsolate);
          await Future.wait<void>(futures);
        };

        restartServer = () async {
          process.stdin.writeln('restart');
        };
      } else {
        reloadServer = () async {
          stdout
            ..writeln('> Hot-Reload not enabled.')
            ..writeln("  Run with '--hot' option.");
        };

        restartServer = () async {
          stdout
            ..writeln('> Hot-Restart not enabled.')
            ..writeln("  Run with '--hot' option.");
        };
      }

      Future<void> stopServer() async {
        var stopped = service.onExtensionEvent.firstWhere(isStopped);
        process.stdin.writeln('stop');
        await stopped;
      }

      void killServer() {
        process.kill();
      }

      if (debug) {
        stdout.writeln('> Debug service listening on $wsUri');
      }

      printServeModeUsage(hot: hot);
      scrout.onData(stdout.writeln);
      screrr.onData(stdout.writeln);
      stdout.write(buffer);
      buffer.clear();

      // TODO(cli): add connection info
      await for (var event in group.stream) {
        if (event == 'r') {
          await reloadServer();
        } else if (event == 'R') {
          await restartServer();
        } else if (event == 'q' ||
            event == ProcessSignal.sigint ||
            event == ProcessSignal.sigterm) {
          stdout.writeln('> Closing ...');
          await stopServer();
          restoreStdinMode();
          break;
        } else if (event == 'Q') {
          // TODO(cli): check force quit
          stdout.writeln('> Force closing ...');
          killServer();
          restoreStdinMode();
          exit(0);
        } else if (event == 's') {
          clearScreen();
        } else if (event == 'S') {
          clearScreen();
          await restartServer();
        } else if (event == 'h') {
          printServeModeUsage();
        } else if (event == 'H') {
          printServeModeUsage(detailed: true, hot: hot);
        } else if (event is String) {
          stdout.writeln("* Unknown key: '$event'");
        } else {
          stdout.writeln('* Unknown event: $event');
        }
      }

      code = await process.exitCode;
    } catch (error, stackTrace) {
      if (buffer.isNotEmpty) {
        stdout.write(buffer);
      }

      stderr
        ..writeln(error)
        ..writeln(stackTrace);

      code = 1;
    } finally {
      await group.close();
    }

    return code;
  }
}

bool isStarted(Event event) {
  return event.extensionKind == 'ext.astra.started';
}

bool isRestarted(Event event) {
  return event.extensionKind == 'ext.astra.restarted';
}

bool isStopped(Event event) {
  return event.extensionKind == 'ext.astra.stopped';
}

void printServeModeUsage({bool detailed = false, bool hot = false}) {
  if (hot) {
    stdout
      ..writeln("> Press 'r' to reload and 'R' to restart.")
      ..writeln("  Press 'q' to quit and 'Q' to force quit.");
  } else {
    stdout.writeln("> Press 'q' to quit and 'Q' to force quit.");
  }

  if (detailed) {
    stdout
      ..writeln("  Press 's' to clear and 'S' to clear and restart after.")
      ..writeln("  To show this detailed help message, press 'H'.");
  } else {
    stdout
      ..writeln("  For a more detailed help message, press 'H'.")
      ..writeln("  To show this help message, press 'h'.");
  }
}

void clearScreen() {
  if (stdout.supportsAnsiEscapes) {
    stdout.write('\x1b[2J\x1b[H');
  } else if (Platform.isWindows) {
    // TODO(cli): windows: reset buffer
    stdout.writeln('* Not supported yet.');
  } else {
    stdout.writeln('* Not supported.');
  }
}
