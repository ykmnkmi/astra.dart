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
import 'dart:isolate' show Isolate;

import 'package:analyzer/dart/analysis/analysis_context_collection.dart'
    show AnalysisContextCollection;
import 'package:analyzer/dart/analysis/results.dart' show ResolvedUnitResult;
import 'package:astra/serve.dart' show ServerType;
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/type.dart';
import 'package:astra_cli/src/version.dart';
import 'package:async/async.dart' show StreamGroup;
import 'package:path/path.dart' show absolute, join, normalize;

class ServeCommand extends CliCommand {
  ServeCommand()
      : name = 'serve',
        description = 'Serve Astra/Shelf application.',
        takesArguments = false {
    argParser
      // application
      ..addSeparator('Application options:')
      ..addOption('target', abbr: 't')

      // server
      ..addSeparator('Server options:')
      ..addOption('server', allowed: <String>['h11'], defaultsTo: 'h11')
      ..addOption('concurrency', abbr: 'j', defaultsTo: '1')
      ..addOption('address', abbr: 'a', defaultsTo: 'localhost')
      ..addOption('port', abbr: 'p', defaultsTo: '8080')
      ..addOption('backlog', defaultsTo: '0')
      ..addFlag('shared', negatable: false)
      ..addFlag('v6Only', negatable: false)
      ..addOption('ssl-cert')
      ..addOption('ssl-key')
      ..addOption('ssl-key-password')

      // debug
      ..addSeparator('Debugging options:')
      ..addFlag('debug', negatable: false)
      ..addOption('debug-port', defaultsTo: '8181')
      ..addMultiOption('watch', abbr: 'w')
      ..addFlag('hot', negatable: false)
      ..addFlag('enable-asserts', negatable: false);
  }

  @override
  final String name;

  @override
  final String description;

  @override
  final bool takesArguments;

  late final target = getString('target') ?? 'application';

  late final targetPath = getString('target-path') ?? library.path;

  late final server = ServerType.values.byName(getString('server') ?? 'h11');

  late final concurrency = getInteger('concurrency') ?? 1;

  late final address = getString('address') ?? 'localhost';

  late final port = getInteger('port') ?? 8080;

  late final backlog = getInteger('backlog') ?? 0;

  late final shared = getBoolean('shared');

  late final v6Only = getBoolean('v6Only');

  late final sslCert = getString('ssl-cert');

  late final sslkey = getString('ssl-key');

  late final sslkeyPassword = getString('ssl-key-password');

  late final debug = getBoolean('debug');

  late final debugPort = getInteger('debug-port');

  late final hot = getBoolean('hot');

  late final watch = watchList.isNotEmpty;

  late final watchList = getStringList('watch').map<String>(normalize).toList();

  late final enableAsserts = getBoolean('enable-asserts');

  void checkConfiguration() {
    if ((sslCert == null) ^ (sslkey == null)) {
      throw CliException("Only 'ssl-cert' or 'ssl-key' is set");
    }

    if (!pubspecFile.existsSync()) {
      throw CliException('${directory.path} is not package');
    }

    if (!library.existsSync()) {
      throw CliException('${library.path} not exists');
    }
  }

  Future<String> createSource(TargetType targetType) async {
    var sslCert = this.sslCert;
    var sslkey = this.sslkey;
    String? context;

    if (sslCert != null && sslkey != null) {
      var certFilePath = absolute(normalize(sslCert));
      var keyFilePath = absolute(normalize(sslkey));
      context = 'SecurityContext()'
          "..useCertificateChain('$certFilePath')"
          "..usePrivateKey('$keyFilePath', password: '$sslkeyPassword')";
    }

    var data = <String, String>{
      'VERSION': packageVersion,
      'PACKAGE': 'package:$package/$package.dart',
      'TARGET': target,
      'SERVER': '$server',
      'CONCURRENCY': '$concurrency',
      'DEBUG': '$debug',
      'HOT': '$hot',
      'VERBOSE': '$verbose',
      'SCHEME': context == null ? 'http' : 'https',
      'ADDRESS': address,
      'PORT': '$port',
      'CONTEXT': '$context',
      'BACKLOG': '$backlog',
      'SHARED': '${shared || concurrency > 1}',
      'V6ONLY': '$v6Only',
    };

    data['SERVE'] = await renderTemplate('serve/_.serve', data);
    data['CREATE'] = await renderTemplate('serve/${targetType.name}', data);
    return renderTemplate('serve', data);
  }

  Future<String> renderTemplate(String name, Map<String, String> data) async {
    var templateUri = Uri(
      scheme: 'package',
      path: 'astra_cli/src/templates/$name.template',
    );

    var templateResolvedUri = await Isolate.resolvePackageUri(templateUri);

    if (templateResolvedUri == null) {
      throw CliException('Serve template uri not resolved');
    }

    var template = await File.fromUri(templateResolvedUri).readAsString();

    String replace(Match match) {
      var variable = match.group(1);

      if (variable == null) {
        throw StateError("Template variable '$variable' not found");
      }

      return data[variable]!;
    }

    return template.replaceAllMapped(RegExp('__([A-Z][0-9A-Z]*)__'), replace);
  }

  @override
  Future<int> handle() async {
    checkConfiguration();

    var includedPaths = <String>[directory.absolute.path];
    var collection = AnalysisContextCollection(includedPaths: includedPaths);
    var context = collection.contextFor(directory.absolute.path);
    var session = context.currentSession;
    var resolvedUnit = await session.getResolvedUnit(library.absolute.path);

    if (resolvedUnit is! ResolvedUnitResult) {
      throw CliException('Library not resolved');
    }

    if (resolvedUnit.errors.isNotEmpty) {
      throw resolvedUnit.errors.first;
    }

    var memberType = TargetType.getFor(resolvedUnit, target: target);
    var source = await createSource(memberType);
    var scriptPath = join('.dart_tool', 'astra.serve-$packageVersion.dart');
    var script = File(join(directory.path, scriptPath));
    script.writeAsStringSync(source);

    List<String> arguments;

    if (hot) {
      arguments = <String>[
        '-DSILENT_OBSERVATORY=true',
        '--enable-vm-service=$debugPort',
        '--disable-service-auth-codes',
        '--no-pause-isolates-on-exit',
        '--no-serve-devtools',
        '--no-dds',
      ];
    } else if (debug) {
      arguments = <String>[
        '-DSILENT_OBSERVATORY=true',
        '--observe=$debugPort',
        '--disable-service-auth-codes',
        '--no-pause-isolates-on-exit',
        '--no-serve-devtools',
      ];
    } else {
      arguments = <String>[];
    }

    if (enableAsserts) {
      arguments.add('--enable-asserts');
    }

    arguments.add(scriptPath);

    var previousEchoMode = stdin.echoMode;
    var previousLineMode = stdin.lineMode;

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
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

    var group = StreamGroup<Object?>()
      ..add(stdin.map<String>(String.fromCharCodes))
      ..add(ProcessSignal.sigint.watch());

    if (watch) {
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

    int code;

    try {
      var process = await Process.start(
        Platform.executable,
        arguments,
        workingDirectory: directory.path,
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
