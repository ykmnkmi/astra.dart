import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:astra/src/cli/command.dart';
import 'package:astra/src/cli/type.dart';
import 'package:path/path.dart';

class ServeCommand extends CliCommand {
  /// @nodoc
  ServeCommand() {
    argParser
      ..addSeparator('Application options:')
      ..addOption('target', //
          abbr: 't',
          help: 'Application target.',
          valueHelp: 'application')
      ..addOption('concurrency', //
          abbr: 'j',
          help: 'Number of isolates.',
          valueHelp: '1')
      ..addSeparator('Server options:')
      ..addOption('address', //
          abbr: 'a',
          help: 'Bind socket to this address.',
          valueHelp: 'localhost')
      ..addOption('port', //
          abbr: 'p',
          help: 'Bind socket to this port.',
          valueHelp: '8080')
      ..addOption('backlog', //
          help: 'Maximum number of connections to hold in backlog.',
          valueHelp: '0')
      ..addFlag('shared', //
          negatable: false,
          help: 'Socket connections distributing.')
      ..addFlag('v6Only', //
          negatable: false,
          help: 'Restrict socket to version 6.')
      ..addOption('ssl-cert', //
          help: 'SSL certificate file.',
          valueHelp: 'path')
      ..addOption('ssl-key', //
          help: 'SSL key file.',
          valueHelp: 'path')
      ..addOption('ssl-key-password', //
          help: 'SSL key file password.',
          valueHelp: 'password')
      ..addSeparator('Debugging options:')
      ..addFlag('reload', //
          abbr: 'r',
          negatable: false,
          help: 'Enable Hot-Reload.')
      ..addOption('observe', //
          abbr: 'o',
          help: 'Enable VM Observer.',
          valueHelp: '8081')
      ..addFlag('asserts', //
          abbr: 'c',
          negatable: false,
          help: 'Enable asserts.');
  }

  @override
  String get name {
    return 'serve';
  }

  @override
  String get description {
    return 'Serve application.';
  }

  String get target {
    return getString('target') ?? 'application';
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
        '..useCertificateChain(\'$certFilePath\')'
        '..usePrivateKey(\'$keyFilePath\', password: \'$password\')';
  }

  bool get reload {
    return getBoolean('reload');
  }

  bool get observe {
    return observePort != null;
  }

  bool get asserts {
    return getBoolean('asserts');
  }

  int? get observePort {
    return getInteger('observe');
  }

  Future<String> renderTemplate(String name, Map<String, String> data) async {
    var templateUri = Uri(scheme: 'package', path: 'astra/src/cli/templates/$name.template');
    var templateResolvedUri = await Isolate.resolvePackageUri(templateUri);

    if (templateResolvedUri == null) {
      throw CliException('serve template uri not resolved');
    }

    var template = await File.fromUri(templateResolvedUri).readAsString();
    return template.replaceAllMapped(RegExp('__([A-Z][0-9A-Z]*)__'), (match) {
      var variable = match.group(1);

      if (variable == null) {
        throw StateError('template variable \'$variable\' not found.');
      }

      return data[variable]!;
    });
  }

  Future<String> createSource(TargetType targetType) async {
    var context = this.context;
    var concurrency = this.concurrency;

    var data = <String, String>{
      'PACKAGE': 'package:$package/$package.dart',
      'TARGET': target,
      'ISAPPLICATION': '${targetType.isApplication}',
      'CONCURRENCY': '$concurrency',
      'SCHEME': context == null ? 'http' : 'https',
      'ADDRESS': address,
      'PORT': '$port',
      'CONTEXT': '$context',
      'BACKLOG': '$backlog',
      'SHARED': '${shared || concurrency > 1}',
      'V6ONLY': '$v6Only',
      'RELOAD': '$reload',
      'OBSERVE': '$observe',
      'DIRECTORY': directory.path,
    };

    data['CREATE'] = await renderTemplate('serve/${targetType.name}', data);
    return renderTemplate('serve', data);
  }

  @override
  Future<int> run() async {
    var collection = AnalysisContextCollection(includedPaths: <String>[directory.absolute.path]);
    var context = collection.contextFor(directory.absolute.path);
    var session = context.currentSession;
    var resolvedUnit = await session.getResolvedUnit(library.absolute.path);

    if (resolvedUnit is! ResolvedUnitResult) {
      throw CliException('library not resolved');
    }

    if (resolvedUnit.errors.isNotEmpty) {
      throw resolvedUnit.errors.first;
    }

    var memberType = getTargetType(target, resolvedUnit);
    var source = await createSource(memberType);
    var scriptPath = join('.dart_tool', 'astra.serve.dart');
    var script = File(join(directory.path, scriptPath));
    await script.writeAsString(source);

    var arguments = <String>[];

    if (reload || observe) {
      arguments.add('-DSILENT_OBSERVATORY=true');
    }

    arguments.add('run');

    if (reload || observe) {
      arguments
        ..add('--enable-vm-service=$observePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-serve-devtools')
        ..add('--no-dds');
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

    try {
      var process = await Process.start('dart', arguments, //
          workingDirectory: directory.path,
          runInShell: true);

      if (Platform.isWindows) {
        ProcessSignal.sigint.watch().listen(process.stdin.writeln);
      } else {
        ProcessSignal.sigterm.watch().listen(process.stdin.writeln);
      }

      stdin.listen(process.stdin.add);
      process.stdout.pipe(stdout);
      process.stderr.pipe(stderr);
      return await process.exitCode;
    } finally {
      stdin
        ..echoMode = echoMode
        ..lineMode = lineMode;
    }
  }
}
