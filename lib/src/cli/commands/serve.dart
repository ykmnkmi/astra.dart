import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:astra/src/cli/command.dart';
import 'package:path/path.dart';

enum TargetType {
  instance,
  controllerInstance,
  applicationInstance,
  type,
  controller,
  application,
  hanlder,
  syncFactory,
  asyncFactory,
}

class ServeCommand extends AstraCommand {
  ServeCommand() {
    argParser
      ..addSeparator('Application options:')
      ..addOption('target', //
          abbr: 't',
          help: 'Application handler, class or factory.',
          valueHelp: 'name',
          defaultsTo: 'application')
      ..addOption('concurrency', //
          abbr: 'j',
          help: 'Number of isolates.',
          valueHelp: 'count',
          defaultsTo: '1')
      ..addSeparator('Server options:')
      ..addOption('address', //
          abbr: 'a',
          help: 'Bind socket to this address.',
          valueHelp: 'internet-address',
          defaultsTo: 'localhost')
      ..addOption('port', //
          abbr: 'p',
          help: 'Bind socket to this port.',
          valueHelp: 'port',
          defaultsTo: '3000')
      ..addOption('backlog', //
          help: 'Maximum number of connections to hold in backlog.',
          valueHelp: 'count',
          defaultsTo: '0')
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
          help: 'SSL keyfile password.',
          valueHelp: 'password')
      ..addSeparator('Debugging options:')
      ..addFlag('reload', //
          abbr: 'r',
          negatable: false,
          help: 'Enable hot-reload.')
      ..addOption('observe', //
          abbr: 'o',
          help: 'Enable VM Observer.',
          valueHelp: 'port',
          defaultsTo: '3001');
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
    return getString('target', 'application');
  }

  int get concurrency {
    var positive = getPositive('concurrency', 1);

    if (positive == 0) {
      return max(1, Platform.numberOfProcessors - 1);
    }

    return positive;
  }

  String get address {
    return getString('address', 'localhost');
  }

  int get port {
    return getPositive('port', 8080);
  }

  int get backlog {
    return getPositive('backlog', 0);
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
    return getBoolean('observe');
  }

  int get observePort {
    return getPositive('observe', 8181);
  }

  TargetType getTargetType() {
    var uri = libraryFile.absolute.uri;
    var featureSet = FeatureSet.latestLanguageVersion();
    var result = parseFile(path: uri.toFilePath(), featureSet: featureSet);

    if (result.errors.isNotEmpty) {
      // TODO: update error
      throw result.errors.first;
    }

    for (var declaration in result.unit.declarations) {
      if (declaration is TopLevelVariableDeclaration) {
        if (declaration.variables.isLate) {
          // TODO: update error
          throw Exception('aplication instance must be initialized.');
        }

        for (var variable in declaration.variables.variables) {
          if (variable.name.name == target) {
            // TODO: check target type
            return TargetType.instance;
          }
        }
      }

      if (declaration is ClassDeclaration && declaration.name.name == target) {
        // TODO: check if target Controller or Application
        return TargetType.type;
      }

      if (declaration is FunctionDeclaration && declaration.name.name == target) {
        if (declaration.isGetter || declaration.isSetter) {
          // TODO: update error
          throw Exception('$target is getter or setter.');
        }

        var type = declaration.returnType;

        if (type == null) {
          // TODO: update error
          throw Exception('$target return type not set.');
        }

        var dartType = type.type;

        if (dartType == null) {
          // TODO: update error
          throw Exception();
        }

        // TODO: check if target function is Handler or factory
        return TargetType.hanlder;
      }
    }

    // TODO: update error
    throw Exception('$target not found');
  }

  Future<String> renderTemplate(String name, Map<String, String> data) async {
    var templateUri = Uri(scheme: 'package', path: 'astra/src/cli/templates/$name.template');
    var templateResolvedUri = await Isolate.resolvePackageUri(templateUri);

    if (templateResolvedUri == null) {
      throw Exception('serve template uri not resolved');
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
      'CONCURRENCY': '$concurrency',
      'ADDRESS': address,
      'PORT': '$port',
      'CONTEXT': '$context',
      'BACKLOG': '$backlog',
      'SHARED': '${shared || concurrency > 1}',
      'V6ONLY': '$v6Only',
      'RELOAD': '$reload',
      'OBSERVE': '$observe',
      'DIRECTORY': directory.path,
      'SCHEME': context == null ? 'http' : 'https',
    };

    var create = await renderTemplate(targetType.name, data);
    data['CREATE'] = create;
    return renderTemplate('serve', data);
  }

  // TODO: check if target or application class exists
  @override
  Future<int> run() async {
    var memberType = getTargetType();
    print(memberType);

    var source = await createSource(memberType);
    var path = join('.dart_tool', 'astra.serve.dart');
    var script = File(join(directory.path, path));
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

    arguments.add(path);

    var process = await Process.start('dart', arguments, workingDirectory: directory.path);
    stdin.pipe(process.stdin);
    process.stdout.pipe(stdout);
    process.stderr.pipe(stderr);

    var sigint = ProcessSignal.sigint.watch().listen(null);

    void onSignal(ProcessSignal signal) {
      sigint.cancel();
      process.kill(ProcessSignal.sigint);
    }

    sigint.onData(onSignal);

    var code = await process.exitCode;
    sigint.cancel();
    return code;
  }
}
