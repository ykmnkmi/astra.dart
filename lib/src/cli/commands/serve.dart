import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/src/cli/command.dart';
import 'package:path/path.dart';

class ServeCommand extends AstraCommand {
  ServeCommand() {
    argParser
      ..addSeparator('Application options:')
      ..addOption('target', //
          abbr: 't',
          help: 'The name of the handler or factory.',
          valueHelp: 'name',
          defaultsTo: 'application')
      ..addSeparator('Server options:')
      ..addOption('host', //
          abbr: 'a',
          help: 'Socket bind host.',
          valueHelp: 'internet-address',
          defaultsTo: 'localhost')
      ..addOption('port', //
          abbr: 'p',
          help: 'Socket bind port.',
          valueHelp: 'port',
          defaultsTo: '3000')
      ..addOption('backlog', //
          help: 'Socket listen backlog.',
          valueHelp: 'count',
          defaultsTo: '0')
      ..addFlag('shared', //
          negatable: false,
          help: 'Socket connections distributing.')
      ..addFlag('v6Only', //
          negatable: false,
          help: 'Restrict socket to version 6.')
      ..addOption('concurrency', //
          abbr: 'j',
          help: 'The number of concurrent servers to serve.',
          valueHelp: 'count',
          defaultsTo: '1')
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
    var target = argResults['target'] as String?;
    return target ?? 'application';
  }

  String get host {
    var host = argResults['host'] as String?;
    return host ?? 'localhost';
  }

  int get port {
    var port = argResults['port'] as String?;

    if (port == null) {
      return 3000;
    }

    return int.parse(port);
  }

  int get backlog {
    var backlog = argResults['backlog'] as String?;

    if (backlog == null) {
      return 3000;
    }

    // TODO: validate value
    return int.parse(backlog);
  }

  bool get shared {
    return wasParsed('shared') || concurrency > 1;
  }

  bool get v6Only {
    return wasParsed('v6Only');
  }

  int get concurrency {
    var concurrency = argResults['concurrency'] as String?;

    if (concurrency == null) {
      return 1;
    }

    if (concurrency == '0') {
      return Platform.numberOfProcessors;
    }

    // TODO: validate value
    return int.parse(concurrency);
  }

  // TODO: validate values
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
    return 'SecurityContext()..useCertificateChain(\'$certFilePath\')..usePrivateKey(\'$keyFilePath\', password: \'$password\')';
  }

  bool get reload {
    return wasParsed('reload');
  }

  bool get observe {
    return wasParsed('observe');
  }

  String get observePort {
    var observe = argResults['observe'] as String?;
    return observe ?? '8181';
  }

  Future<String> createSource() async {
    var templateUri = Uri(scheme: 'package', path: 'astra/src/cli/templates/serve.dart.template');
    var uri = await Isolate.resolvePackageUri(templateUri);

    if (uri == null) {
      // TODO: update error
      throw StateError('serve template not found');
    }

    var template = await File.fromUri(uri).readAsString();

    var package = 'package:${this.package}/${this.package}.dart';
    var port = '${this.port}';
    var context = '${this.context}';
    var backlog = '${this.backlog}';
    var shared = '${this.shared}';
    var v6Only = '${this.v6Only}';
    var reload = '${this.reload}';
    var observe = '${this.observe}';
    var concurrency = '${this.concurrency}';
    var directory = this.directory.path;
    var scheme = context == 'null' ? 'http' : 'https';

    return template.replaceAllMapped(RegExp('__([A-Z][0-9A-Z]*)__'), (match) {
      var variable = match.group(1);

      switch (variable) {
        case 'PACKAGE':
          return package;
        case 'TARGET':
          return target;
        case 'HOST':
          return host;
        case 'PORT':
          return port;
        case 'CONTEXT':
          return context;
        case 'BACKLOG':
          return backlog;
        case 'SHARED':
          return shared;
        case 'V6ONLY':
          return v6Only;
        case 'RELOAD':
          return reload;
        case 'OBSERVE':
          return observe;
        case 'CONCURRENCY':
          return concurrency;
        case 'DIRECTORY':
          return directory;
        case 'SCHEME':
          return scheme;
        default:
          // TODO: update error
          throw UnsupportedError('template variable: $variable');
      }
    });
  }

  @override
  Future<int> run() async {
    var source = await createSource();
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
