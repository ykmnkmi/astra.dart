import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show min, max;

import 'package:astra/src/cli/command.dart';
import 'package:astra/src/serve/supervisor.dart';
import 'package:path/path.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:vm_service/vm_service_io.dart';

class ServeCommand extends AstraCommand {
  ServeCommand() {
    argParser
      ..addSeparator('Application options:')
      ..addOption('target', //
          abbr: 't',
          help: 'The name of the handler or factory.',
          valueHelp: 'application')
      ..addSeparator('Server options:')
      ..addOption('host', //
          abbr: 'a',
          help: 'Socket bind host.',
          valueHelp: 'localhost')
      ..addOption('port', //
          abbr: 'p',
          help: 'Socket bind port.',
          valueHelp: '3000')
      ..addOption('backlog', //
          help: 'Socket listen backlog.',
          valueHelp: '0')
      ..addFlag('shared', //
          negatable: false,
          help: 'Socket connections distributing.')
      ..addFlag('v6Only', //
          negatable: false,
          help: 'Restrict socket to version 6.')
      ..addOption('concurrency', //
          abbr: 'j',
          help: 'The number of concurrent servers to serve.',
          defaultsTo: '0',
          valueHelp: '4')
      ..addOption('ssl-cert', //
          help: 'SSL certificate file.',
          valueHelp: 'path-to-file')
      ..addOption('ssl-key', //
          help: 'SSL key file.',
          valueHelp: 'path-to-file')
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
          help: 'Enables the VM Observer.');
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
      return Platform.numberOfProcessors - 1;
    }

    return min(max(1, int.parse(concurrency)), Platform.numberOfProcessors - 1);
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
    certFilePath = toUri(normalize(certFilePath)).toFilePath(windows: false);
    keyFilePath = toUri(normalize(keyFilePath)).toFilePath(windows: false);
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

  String createSource() {
    var path = libraryFile.absolute.uri.toString();
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';

import '$path' as _;

Future<void> main(List<String> arguments, SendPort sendPort) async {
  ApplicationManager.setup();

  var handler = await getHandler(_.$target);
  IsolateServer(sendPort, handler, '$host', $port, //
      context: $context,
      backlog: $backlog,
      shared: $shared,
      v6Only: $v6Only,
      launch: true);
}

''';
  }

  @override
  Future<int> run() async {
    if (reload || observe) {
      var info = await Service.controlWebServer(enable: true, silenceOutput: true);

      if (observe) {
        var uri = info.serverUri;

        if (uri == null) {
          // TODO: update error
          throw StateError('observe: no server uri');
        }

        stdout.writeln('* observatory listening on $uri');
      }
    }

    var source = createSource();
    var scriptUri = Uri.dataFromString(source, mimeType: 'application/dart');

    var shutdown = <FutureOr<void> Function()>[];
    var supervisors = <IsolateSupervisor>[];

    for (var i = 1; i <= concurrency; i += 1) {
      var supervisor = IsolateSupervisor(scriptUri, 'isolate/$i');
      stdout.writeln('* starting isolate/$i');
      await supervisor.start();
      supervisors.add(supervisor);
      shutdown.add(supervisor.stop);
    }

    if (concurrency > 1) {
      stdout.writeln('* all isolates started');
    }

    var completer = Completer<int>();

    if (reload) {
      var info = await Service.getInfo();
      var uri = info.serverWebSocketUri;

      if (uri == null) {
        // TODO: update error
        throw StateError('reload: no vm service ws uri');
      }

      var service = await vmServiceConnectUri(uri.toString());
      shutdown.add(service.dispose);

      var isolateIds = <String>[];

      for (var supervisor in supervisors) {
        var id = Service.getIsolateID(supervisor.isolate);

        if (id == null) {
          // TODO: update error
          throw StateError('${supervisor.name} id == null');
        }

        isolateIds.add(id);
      }

      var directory = Directory(join(this.directory.path, 'lib'));

      Future<void> reload(FileSystemEvent event) async {
        stdout.writeln('* reloading...');

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
      stdout.writeln('* watching ${toUri(directory.path).toFilePath(windows: false)}');
    }

    var sigint = ProcessSignal.sigint.watch().listen(null, onError: completer.completeError);

    void onSignal(ProcessSignal signal) async {
      await shutAll(shutdown);

      if (completer.isCompleted) {
        return;
      }

      completer.complete(2);
    }

    sigint.onData(onSignal);
    shutdown.add(sigint.cancel);

    var scheme = context == null ? 'http' : 'https';
    stdout.writeln('* serving at $scheme://$host:$port');
    return completer.future;
  }

  static Future<void> shutAll(List<void Function()> shutdown) {
    return Future.forEach<FutureOr<void> Function()>(shutdown.reversed, (callback) => callback());
  }
}
