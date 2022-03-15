import 'dart:async';
import 'dart:io';

import 'package:astra/src/cli/command.dart';
import 'package:astra/src/cli/path.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:vm_service/vm_service_io.dart';

class ServeCommand extends AstraCommand {
  ServeCommand() {
    argParser
      ..addSeparator('Application options:')
      ..addOption('target', help: 'The name of the handler or factory.', valueHelp: 'application')
      ..addSeparator('Server options:')
      ..addOption('host', help: 'Socket bind host.', valueHelp: 'localhost')
      ..addOption('port', help: 'Socket bind port.', valueHelp: '3000')
      ..addOption('backlog', help: 'Socket listen backlog.', valueHelp: '0')
      ..addFlag('shared', negatable: false, help: 'Socket connections distributing.')
      ..addFlag('v6Only', negatable: false, help: 'Restrict socket to version 6.')
      ..addOption('concurrency', help: 'The number of concurrent servers to serve.', valueHelp: '1')
      ..addOption('ssl-cert', help: 'SSL certificate file.')
      ..addOption('ssl-key', help: 'SSL key file.')
      ..addOption('ssl-key-password', help: 'SSL keyfile password.')
      ..addSeparator('Debugging options:')
      ..addFlag('reload', negatable: false, help: 'Enable hot-reload.')
      ..addOption('observe', help: 'Enables the VM Observer.', valueHelp: '8181');
  }

  @override
  String get name {
    return 'serve';
  }

  @override
  String get description {
    return 'Serve shelf application.';
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

    return int.parse(backlog);
  }

  bool get shared {
    return wasParsed('shared');
  }

  bool get v6Only {
    return wasParsed('v6Only');
  }

  int get concurrency {
    var concurrency = argResults['concurrency'] as String?;

    if (concurrency == null) {
      return 1;
    }

    return int.parse(concurrency);
  }

  // TODO: check relative or absolute path
  // TODO: validate values
  String? get context {
    if (wasParsed('ssl-cert')) {
      if (wasParsed('ssl-key')) {
        if (wasParsed('ssl-key-password')) {
          var certfile = argResults['ssl-cert'] as String;
          var keyfile = argResults['ssl-key'] as String;
          var password = argResults['ssl-key-password'] as String;
          return 'SecurityContext()..useCertificateChain(\'$certfile\')..usePrivateKey(\'$keyfile\', password: \'$password\')';
        }

        throw Exception('usage');
      }

      throw Exception('usage');
    }

    return '';
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

  String createSource() {
    var path = libraryFile.absolute.uri.toString();
    var scheme = context == null ? 'http' : 'https';
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/cli.dart';
import 'package:astra/serve.dart';

import '$path' as _;

Future<void> main() async {
  ApplicationManager.init();

  await serve(_.$target, '$host', $port,
    context: $context,
    concurrency: $concurrency,
    backlog: $backlog,
    shared: $shared,
    v6Only: $v6Only);
  print('serving at $scheme://$host:$port');
}

''';
  }

  @override
  Future<int> run() async {
    var source = createSource();

    var shutdown = <FutureOr<void> Function()>[];
    var arguments = <String>['run'];

    if (reload || observe) {
      arguments
        ..add('--enable-vm-service=$observePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-serve-devtools')
        ..add('--no-dds');
    }

    var script = File(join(directory.path, '.dart_tool', 'astra-$package.dart'));
    await script.writeAsString(source);
    shutdown.add(() => script.delete());
    arguments.add(script.path);

    var completer = Completer<int>();
    var process = await Process.start(Platform.executable, arguments);

    void onExit(int code) {
      if (completer.isCompleted) {
        return;
      }

      completer.complete(code);
    }

    process.exitCode.then<void>(onExit);

    void onError(List<int> bytes) async {
      stderr.add(bytes);
      await shutAll(shutdown);

      if (completer.isCompleted) {
        return;
      }

      completer.complete(1);
    }

    process.stderr.listen(onError, onError: completer.completeError);
    shutdown.add(process.kill);

    if (reload) {
      var output = process.stdout.listen(null, onError: completer.completeError);

      void onOut(List<int> bytes) {
        output.pause();

        var message = String.fromCharCodes(bytes);

        if (message.startsWith('Observatory')) {
          output.resume();
          return;
        }

        stdout.add(bytes);

        output
          ..onData(stdout.add)
          ..resume();
      }

      output.onData(onOut);

      var service = await vmServiceConnectUri('ws://localhost:$observePort/ws');
      shutdown.add(service.dispose);

      var vm = await service.getVM();
      var isolateIds = <String>[];
      var isolates = vm.isolates;

      if (isolates == null) {
        // TODO: update error
        throw Exception('WTF Dart?');
      }

      for (var isolateRef in isolates) {
        var id = isolateRef.id;

        if (id == null) {
          // TODO: update error
          throw Exception('WTF Dart?');
        }

        isolateIds.add(id);
      }

      var directory = Directory(join(this.directory.path, 'lib'));

      Future<void> reload(FileSystemEvent event) {
        stdout.writeln('reloading...');

        Future<void> onEach(String isolateId) async {
          var result = await service.reloadSources(isolateId);

          if (result.success == true) {
            service.callServiceExtension('ext.astra.reasemble', isolateId: isolateId);
          }
        }

        return Future.forEach<String>(isolateIds, onEach);
      }

      var watch = directory
          .watch(events: FileSystemEvent.modify, recursive: true)
          .throttle(Duration(seconds: 1))
          .asyncMapSample(reload)
          .listen(null, onError: completer.completeError);
      shutdown.add(watch.cancel);
    } else {
      process.stdout.listen(stdout.add);
    }

    var sigint = ProcessSignal.sigint.watch().listen(null, onError: completer.completeError);

    void onSignal(ProcessSignal signal) async {
      await shutAll(shutdown);
      await sigint.cancel();

      if (completer.isCompleted) {
        return;
      }

      completer.complete(2);
    }

    sigint.onData(onSignal);
    return completer.future;
  }

  static Future<void> shutAll(List<void Function()> shutdown) {
    return Future.forEach<FutureOr<void> Function()>(shutdown.reversed, (callback) => callback());
  }
}
