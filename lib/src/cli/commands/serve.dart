import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astra/src/cli/command.dart';
import 'package:astra/src/cli/path.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

class ServeCommand extends AstraCommand {
  ServeCommand() {
    argParser
      ..addSeparator('Application options:')
      ..addOption('target',
          abbr: 't', help: 'The name of the handler or factory to serve requests.')
      ..addSeparator('Debugging options:')
      ..addFlag('reload', abbr: 'r', negatable: false, help: '')
      ..addOption('observe',
          help: 'Enables the VM service on the specified port for connections.', valueHelp: '8181')
      ..addFlag('verbose',
          abbr: 'v', negatable: false, help: 'Output more informational messages.');
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

  bool get reload {
    return argResults.wasParsed('reload');
  }

  bool get observe {
    return argResults.wasParsed('observe');
  }

  String get observePort {
    var observe = argResults['observe'] as String?;
    return observe ?? '8181';
  }

  @override
  Future<int> run() async {
    var uri = libraryFile.absolute.uri;
    var source = createSource(uri, target);
    var shutdownCallbacks = <FutureOr<void> Function()>[];
    var arguments = <String>['run'];

    if (reload || observe) {
      arguments
        ..add('--enable-vm-service=$observePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-serve-devtools')
        ..add('--no-dds');
    }

    var dartToolPath = '.dart_tool${Platform.pathSeparator}astra';
    var dartTool = Directory(dartToolPath);
    dartTool.createSync(recursive: true);

    var script = File('$dartToolPath${Platform.pathSeparator}$package.dart');
    script.writeAsStringSync(source);
    shutdownCallbacks.add(() => dartTool.deleteSync(recursive: true));
    arguments.add(script.path);

    var completer = Completer<int>();
    var process = await Process.start(Platform.executable, arguments);
    process.stderr.listen(stderr.add, onError: completer.completeError);
    shutdownCallbacks.add(process.kill);

    if (reload) {
      var output = process.stdout.listen(null, onError: completer.completeError);
      output.onData((bytes) {
        output.pause();

        var message = utf8.decode(bytes);

        if (message.startsWith('Observatory')) {
          output.resume();
          return;
        }

        stdout.add(bytes);

        output
          ..onData(stdout.add)
          ..resume();
      });

      var service = await vmServiceConnectUri('ws://localhost:$observePort/ws');
      shutdownCallbacks.add(service.dispose);

      var vm = await service.getVM();
      var isolateIds = <String>[];
      var isolates = vm.isolates;

      if (isolates == null) {
        throw Exception('WTF Dart?');
      }

      for (var isolateRef in isolates) {
        var id = isolateRef.id;

        if (id == null) {
          throw Exception('WTF Dart?');
        }

        isolateIds.add(id);
      }

      var directory = Directory(join(this.directory.path, 'lib'));

      Future<void> reloader(FileSystemEvent event) {
        stdout.writeln('Reloading...');
        return Future.forEach<String>(isolateIds, (isolateId) async {
          var result = await service.reloadSources(isolateId);

          if (result.success == true) {
            await service.callServiceExtension('ext.astra.reasemble', isolateId: isolateId);
          }
        });
      }

      var watch = directory
          .watch(events: FileSystemEvent.modify, recursive: true)
          .throttle(Duration(seconds: 1))
          .asyncMapSample(reloader)
          .listen(null, onError: completer.completeError);
      shutdownCallbacks.add(watch.cancel);
    } else {
      process.stdout.listen(stdout.add);
    }

    var sigint = ProcessSignal.sigint.watch().listen(null, onError: completer.completeError);
    sigint.onData((signal) {
      for (var callback in shutdownCallbacks.reversed) {
        callback();
      }

      sigint.cancel();
      completer.complete(130);
    });

    return completer.future;
  }

  String createSource(Uri uri, String target,
      {bool secure = false, Object address = 'localhost', int port = 3000}) {
    var scheme = secure ? 'https' : 'http';
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/cli.dart';
import 'package:astra/serve.dart';

import '$uri' as _;

Future<void> main() async {
  ApplicationManager.init();

  await serve(_.$target, 'localhost', $port);
  print('serving at $scheme://$address:$port');
}

''';
  }
}
