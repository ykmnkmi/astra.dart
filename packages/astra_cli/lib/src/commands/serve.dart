import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:astra/serve.dart';
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/type.dart';
import 'package:astra_cli/src/version.dart';
import 'package:path/path.dart';

class ServeCommand extends CliCommand {
  ServeCommand() {
    argParser
      // application
      ..addSeparator('Application options:')
      ..addOption('target', abbr: 't', help: 'Serve target.')

      // server
      ..addSeparator('Server options:')
      ..addOption('server-type',
          abbr: 's',
          help: 'Server type.',
          allowed: <String>['h11'],
          allowedHelp: <String, String>{'h11': 'Default HTTP/1.1 adapter.'})
      ..addOption('concurrency', abbr: 'j', help: 'Number of isolates to run.')
      ..addOption('address', abbr: 'a', help: 'The address to listen.')
      ..addOption('port', abbr: 'p', help: 'The port to listen.')
      ..addOption('backlog',
          help: 'Maximum number of connections to hold in backlog.')
      ..addFlag('shared',
          negatable: false, help: 'Socket connections distributing.')
      ..addFlag('v6Only',
          negatable: false, help: 'Restrict connections to version 6.')
      ..addOption('ssl-cert', help: 'The path to a SSL certificate.')
      ..addOption('ssl-key', help: 'The path to a private key.')
      ..addOption('ssl-key-password', help: 'The password of private key file.')

      // debug
      ..addSeparator('Debugging options:')
      ..addFlag('reload', negatable: false, help: 'Enable hot-reload.')
      ..addFlag('watch', negatable: false, help: "Enable 'lib' folder watcher.")
      ..addOption('debug', help: 'Enable VM observer.')
      ..addFlag('asserts', help: 'Enable asserts.');
  }

  @override
  String get name {
    return 'serve';
  }

  @override
  String get description {
    return 'Serve Astra/Shelf application.';
  }

  String get target {
    return getString('target') ?? 'application';
  }

  String get targetPath {
    return getString('target-path') ?? library.path;
  }

  ServerType get serverType {
    var type = getString('server-type') ?? 'h11';
    return ServerType.values.byName(type);
  }

  int get concurrency {
    var positive = getInteger('concurrency') ?? 1;

    if (positive == 0) {
      return max(1, Platform.numberOfProcessors - 1);
    }

    return positive;
  }

  String get address {
    return getString('address') ?? 'localhost';
  }

  int get port {
    return getInteger('port') ?? 8080;
  }

  int get backlog {
    return getInteger('backlog') ?? 0;
  }

  bool get shared {
    return getBoolean('shared');
  }

  bool get v6Only {
    return getBoolean('v6Only');
  }

  String? get context {
    var certFilePath = argResults['ssl-cert'] as String?;

    if (certFilePath == null) {
      return null;
    }

    var keyFilePath = argResults['ssl-key'] as String?;

    if (keyFilePath == null) {
      return null;
    }

    var password = argResults['ssl-key-password'] as String?;
    certFilePath = absolute(normalize(certFilePath));
    keyFilePath = absolute(normalize(keyFilePath));
    return 'SecurityContext()'
        "..useCertificateChain('$certFilePath')"
        "..usePrivateKey('$keyFilePath', password: '$password')";
  }

  bool get observe {
    return observePort != null;
  }

  int? get observePort {
    return getInteger('observe');
  }

  bool get reload {
    return getBoolean('reload');
  }

  bool get watch {
    return getBoolean('watch');
  }

  bool get asserts {
    return getBoolean('asserts');
  }

  Future<String> renderTemplate(String name, Map<String, String> data) async {
    var templateUri = Uri(
      scheme: 'package',
      path: 'astra/src/cli/templates/$name.template',
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

  Future<String> createSource(TargetType targetType) async {
    var context = this.context;
    var concurrency = this.concurrency;

    var data = <String, String>{
      'VERSION': packageVersion,
      'PACKAGE': 'package:$package/$package.dart',
      'TARGET': target,
      'SERVERTYPE': '$serverType',
      'CONCURRENCY': '$concurrency',
      'OBSERVE': '$observe',
      'RELOAD': '$reload',
      'WATCH': '$watch',
      'ASSERTS': '$asserts',
      'VERBOSE': '$reload',
      'SCHEME': context == null ? 'http' : 'https',
      'ADDRESS': address,
      'PORT': '$port',
      'CONTEXT': '$context',
      'BACKLOG': '$backlog',
      'SHARED': '${shared || concurrency > 1}',
      'V6ONLY': '$v6Only',
    };

    data['APPLICATIONSERVE'] = await renderTemplate('serve/_.serve', data);
    data['CREATE'] = await renderTemplate('serve/${targetType.name}', data);
    return renderTemplate('serve', data);
  }

  @override
  Future<int> handle() async {
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

    var arguments = <String>['-DASTRA_CLI=true'];

    if (reload) {
      arguments
        ..add('-DSILENT_OBSERVATORY=true')
        ..add('--enable-vm-service=$observePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-pause-isolates-on-exit')
        ..add('--no-serve-devtools')
        ..add('--no-dds');
    } else if (observe) {
      arguments
        ..add('-DSILENT_OBSERVATORY=true')
        ..add('--observe=$observePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-pause-isolates-on-exit')
        ..add('--no-serve-devtools');
    }

    if (asserts) {
      arguments.add('--enable-asserts');
    }

    arguments.add(scriptPath);

    var echoMode = stdin.echoMode;
    var lineMode = stdin.lineMode;

    stdin
      ..echoMode = false
      ..lineMode = false;

    StreamSubscription<List<int>>? stdinSubscription;
    StreamSubscription<ProcessSignal>? sigintSubscription;

    try {
      var process = await Process.start(
        Platform.executable,
        arguments,
        workingDirectory: directory.path,
      );

      sigintSubscription = ProcessSignal.sigint //
          .watch()
          .listen(process.stdin.writeln);
      stdinSubscription = stdin.listen(process.stdin.add);
      process.stdout.pipe(stdout);
      process.stderr.pipe(stderr);
      return await process.exitCode;
    } finally {
      stdin
        ..lineMode = lineMode
        ..echoMode = echoMode;

      stdinSubscription?.cancel();
      sigintSubscription?.cancel();
    }
  }
}
