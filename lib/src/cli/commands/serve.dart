import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:astra/serve.dart';
import 'package:astra/src/cli/command.dart';
import 'package:astra/src/cli/type.dart';
import 'package:astra/src/core/version.dart';
import 'package:path/path.dart';

class ServeCommand extends CliCommand {
  ServeCommand() {
    argParser
      // application
      ..addSeparator('Application options:')
      ..addOption('target', //
          abbr: 't',
          help: 'Serve target.',
          valueHelp: 'application')

      // server
      ..addSeparator('Server options:')
      ..addOption('server-type', //
          abbr: 's',
          help: 'Server type.',
          allowed: <String>['shelf', 'h11'],
          allowedHelp: <String, String>{
            'shelf': 'Default shelf adapter.',
            'h11': 'Experimental HTTP/1.1 adapter.',
          },
          valueHelp: 'shelf')
      ..addOption('concurrency', //
          abbr: 'j',
          help: 'Number of isolates to run.',
          valueHelp: '1')
      ..addOption('address', //
          abbr: 'a',
          help: 'The address to listen.',
          valueHelp: 'localhost')
      ..addOption('port', //
          abbr: 'p',
          help: 'The port to listen.',
          valueHelp: '8080')
      ..addOption('backlog', //
          help: 'Maximum number of connections to hold in backlog.',
          valueHelp: '0')
      ..addFlag('shared', //
          negatable: false,
          help: 'Socket connections distributing.')
      ..addFlag('v6Only', //
          negatable: false,
          help: 'Restrict connections to version 6.')
      ..addOption('ssl-cert', //
          help: 'The path to a SSL certificate.',
          valueHelp: 'path')
      ..addOption('ssl-key', //
          help: 'The path to a private key.',
          valueHelp: 'path')
      ..addOption('ssl-key-password', //
          help: 'The password of private key file.',
          valueHelp: 'passphrase')

      // debug
      ..addSeparator('Debugging options:')
      ..addFlag('reload', //
          abbr: 'r',
          negatable: false,
          help: 'Enable hot-reload and hot-restart.')
      ..addFlag('watch', //
          abbr: 'w',
          negatable: false,
          help: 'Watch lib folder for changes and perform hot-reload.')
      ..addOption('observe', //
          abbr: 'o',
          help: 'Enable VM observer.',
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

  ServerType get serverType {
    var type = getString('address') ?? 'shelf';
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
        '..useCertificateChain(\'$certFilePath\')'
        '..usePrivateKey(\'$keyFilePath\', password: \'$password\')';
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
    var templateUri = Uri(scheme: 'package', path: 'astra/src/cli/templates/$name.template');
    var templateResolvedUri = await Isolate.resolvePackageUri(templateUri);

    if (templateResolvedUri == null) {
      throw CliException('serve template uri not resolved');
    }

    var template = await File.fromUri(templateResolvedUri).readAsString();

    String replace(Match match) {
      var variable = match.group(1);

      if (variable == null) {
        throw StateError('template variable \'$variable\' not found.');
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

    var memberType = TargetType.getFor(resolvedUnit, target: target);
    var source = await createSource(memberType);
    var scriptPath = join('.dart_tool', 'astra.serve.dart');
    var script = File(join(directory.path, scriptPath));
    script.writeAsStringSync(source);

    var arguments = <String>[];

    if (reload || observe) {
      arguments.add('-DSILENT_OBSERVATORY=true');
    }

    arguments.add('run');

    if (reload) {
      arguments
        ..add('--enable-vm-service=$observePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-serve-devtools')
        ..add('--no-dds');
    } else if (observe) {
      arguments.add('--observe=$observePort');
    }

    if (asserts) {
      arguments.add('--enable-asserts');
    }

    arguments
      ..add(scriptPath)
      ..add('--overriden');

    var echoMode = stdin.echoMode;
    var lineMode = stdin.lineMode;

    stdin
      ..echoMode = false
      ..lineMode = false;

    late StreamSubscription<List<int>> stdinSubscription;
    late StreamSubscription<ProcessSignal> sigintSubscription;

    try {
      var process = await Process.start(Platform.executable, arguments, //
          workingDirectory: directory.path);

      sigintSubscription = ProcessSignal.sigint.watch().listen(process.stdin.writeln);
      stdinSubscription = stdin.listen(process.stdin.add);
      process.stdout.pipe(stdout);
      process.stderr.pipe(stderr);
      return await process.exitCode;
    } finally {
      stdin
        ..echoMode = echoMode
        ..lineMode = lineMode;

      stdinSubscription.cancel();
      sigintSubscription.cancel();
    }
  }
}
