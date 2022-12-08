import 'dart:async';
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
import 'package:path/path.dart' show join, normalize;

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
              ' be accepted.\nUse v6Only to set version 6 only.',
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

  late final ServerType serverType =
      ServerType.values.byName(getString('server-type') ?? 'h11');

  late final int concurrency = getInteger('concurrency') ?? 0;

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

  late final bool? enableAsserts = getBoolean('enable-asserts');

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
      serveTemplate = 'serve';
      data['SSLKEY'] = "'$sslKey'";
      data['SSLCERT'] = "'$sslCert'";
      data['SSLKEYPASSWORD'] = sslKeyPass == null ? 'null' : "'$sslKeyPass'";
    } else {
      serveTemplate = 'serveSecure';
    }

    data['SERVE'] = await renderTemplate('serve/_.$serveTemplate', data);
    data['CREATE'] = await renderTemplate('serve/${targetType.name}', data);
    return await renderTemplate('serve', data);
  }

  @override
  Future<int> handle() async {
    var includedPaths = <String>[workingDirectory.absolute.path];
    var collection = AnalysisContextCollection(includedPaths: includedPaths);
    var context = collection.contextFor(workingDirectory.absolute.path);
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
    var scriptPath = join('.dart_tool', 'astra.serve-$cliVersion.dart');
    var script = File(join(workingDirectory.path, scriptPath));
    script.writeAsStringSync(source);

    var arguments = <String>[for (var define in defineList) '-D$define'];

    if (debug) {
      arguments += <String>[
        '-DSILENT_OBSERVATORY=true',
        '--observe=$servicePort',
        '--disable-service-auth-codes',
        '--no-serve-devtools',
      ];
    } else if (hot) {
      arguments += <String>[
        '-DSILENT_OBSERVATORY=true',
        '--enable-vm-service=$servicePort',
        '--disable-service-auth-codes',
        '--no-pause-isolates-on-exit',
        '--no-serve-devtools',
        '--no-dds',
      ];
    }

    if (enableAsserts ?? debug) {
      arguments.add('--enable-asserts');
    }

    arguments.add(scriptPath);

    var previousEchoMode = stdin.echoMode;
    var previousLineMode = stdin.lineMode;

    try {
      stdin
        ..echoMode = false
        ..lineMode = false;
    } on StdinException {
      // TODO(*): log error
    }

    void restoreStdinMode() {
      try {
        stdin.lineMode = previousLineMode;

        if (previousLineMode) {
          stdin.echoMode = previousEchoMode;
        }
      } on StdinException {
        // TODO(*): log error
      }
    }

    Future<void> Function() reload;

    Future<void> Function() restart;

    if (hot) {
      throw UnimplementedError();
    } else {
      reload = () async {
        stdout
          ..writeln('* Hot-Reload not enabled.')
          ..writeln("  Run with '--hot' option.");
      };

      restart = () async {
        stdout
          ..writeln('* Hot-Restart not enabled.')
          ..writeln("  Run with '--hot' option.");
      };
    }

    var group = StreamGroup<Object?>()
      ..add(stdin.map<String>(String.fromCharCodes))
      ..add(ProcessSignal.sigint.watch());

    int code;

    try {
      var process = await Process.start(
        Platform.executable,
        arguments,
        workingDirectory: workingDirectory.path,
      );

      process
        ..stdout.pipe(stdout)
        ..stderr.pipe(stderr);

      printServeModeUsage();

      // TODO(*): add connection info
      await for (var event in group.stream) {
        if (event == 'r') {
          await reload();
        } else if (event == 'R') {
          await restart();
        } else if (event == 'q') {
          stdout.writeln('> Closing ...');
          break;
        } else if (event == 'Q' || event is ProcessSignal) {
          stdout.writeln('> Force closing ...');
          restoreStdinMode();
          exit(0);
        } else if (event == 's') {
          clearScreen();
        } else if (event == 'S') {
          clearScreen();
          await restart();
        } else if (event == 'h') {
          stdout.writeln('');
          printServeModeUsage();
        } else if (event == 'H') {
          stdout.writeln('');
          printServeModeUsage(detailed: true);
        } else if (event is String) {
          stdout.writeln("* Unknown key: '$event'");
        } else {
          stdout.writeln('* Unknown event: $event');
        }
      }

      code = 0;
    } catch (error) {
      stderr.writeln(error);
      code = 1;
    } finally {
      restoreStdinMode();
      await group.close();
    }

    return code;
  }
}

void clearScreen() {
  if (stdout.supportsAnsiEscapes) {
    stdout.write('\x1b[2J\x1b[H');
  } else if (Platform.isWindows) {
    // TODO(*): windows: reset buffer
    stdout.writeln('* Not supported yet.');
  } else {
    stdout.writeln('* Not supported.');
  }
}

void printServeModeUsage({bool detailed = false}) {
  stdout
    ..writeln("* Press 'r' to reload and 'R' to restart.")
    ..writeln("  Press 'q' to quit and 'Q' to force quit.");

  if (detailed) {
    stdout
      ..writeln("  Press 's' to clear and 'S' to clear and restart after.")
      ..writeln("  To show this detailed help message, press 'H'.");
  } else {
    stdout
      ..writeln("  To show this help message, press 'h'.")
      ..writeln("  For a more detailed help message, press 'H'.");
  }

  stdout.writeln();
}
