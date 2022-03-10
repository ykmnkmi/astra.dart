import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:astra/src/cli/project.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:vm_service/vm_service.dart' show Log;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

class ServeCommand extends Command<int> with Project {
  ServeCommand() {
    argParser
      ..addOption('target', abbr: 't')
      ..addFlag('reload', abbr: 'r')
      ..addOption('service-port')
      ..addFlag('verbose', abbr: 'v');
  }

  @override
  String get name {
    return 'serve';
  }

  @override
  String get description {
    return 'Serve an file or package.';
  }

  @override
  String get invocation {
    var parents = <String>[name];
    var command = parent;

    while (command != null) {
      parents.add(command.name);
      command = command.parent;
    }

    parents.add(runner!.executableName);

    var invocation = parents.reversed.join(' ');
    return '$invocation [options] [pacakge|file]';
  }

  String get target {
    return argResults['target'] as String? ?? 'application';
  }

  bool get hotReload {
    var reload = argResults['reload'] as bool?;
    return reload == true;
  }

  String get servicePort {
    var servicePort = argResults['service-port'] as String?;
    return servicePort ?? '8181';
  }

  bool get verbose {
    var reload = argResults['verbose'] as bool?;
    return reload == true;
  }

  @override
  ArgResults get argResults {
    return super.argResults!;
  }

  @override
  Future<int> run() async {
    var rest = argResults.rest;
    var length = rest.length;

    if (length == 0) {
      usageException('Must specify an package or file to serve.');
    }

    if (length > 1) {
      usageException('Must specify one package or file to serve.');
    }

    var path = rest[0];
    File file;
    Uri uri;

    if (FileSystemEntity.isFileSync(path)) {
      file = File(path);
      uri = file.absolute.uri;
    } else {
      if (!path.contains('/')) {
        path = '$path/$path';
      }

      if (!path.startsWith('package:')) {
        path = 'package:$path';
      }

      if (!path.endsWith('.dart')) {
        path = '$path.dart';
      }

      uri = Uri.parse(path);

      var resolvedPackageUri = await Isolate.resolvePackageUri(uri);

      if (resolvedPackageUri == null) {
        throw Exception();
      }

      file = File.fromUri(resolvedPackageUri);
      uri = file.uri;
    }

    if (file.existsSync()) {
      // TODO: check target
    } else {
      throw Exception('file not found');
    }

    var source = createSource(uri, target);

    var shutdownCallbacks = <FutureOr<void> Function()>[];
    var arguments = <String>['run'];

    if (hotReload) {
      arguments
        ..add('--enable-vm-service=$servicePort')
        ..add('--disable-service-auth-codes')
        ..add('--no-serve-devtools')
        ..add('--no-dds');
    }

    var dartTool = Directory.fromUri(directory.uri.resolveUri(Uri(path: '.dart_tool/astra')));
    dartTool.createSync(recursive: true);
    var script = File.fromUri(dartTool.uri.resolveUri(Uri(path: '$package.dart')));
    script.writeAsStringSync(source);
    shutdownCallbacks.add(() => dartTool.deleteSync(recursive: true));
    arguments.add(script.path);

    var completer = Completer<int>();
    var process = await Process.start(Platform.executable, arguments);
    process.stderr.listen(stderr.add);
    shutdownCallbacks.add(process.kill);

    if (hotReload) {
      var output = process.stdout.listen(null);
      output.onData((bytes) {
        output.pause();

        var message = utf8.decode(bytes);

        if (message.startsWith('Observatory') || message.startsWith('The Dart DevTools debugger')) {
          output.resume();
          return;
        }

        stdout.add(bytes);

        output
          ..onData(stdout.add)
          ..resume();
      });

      var service = await vmServiceConnectUri('ws://localhost:$servicePort/ws', log: StdoutLog());
      shutdownCallbacks.add(service.dispose);

      var vm = await service.getVM();
      var isolateRef = vm.isolates![0];
      var isolateId = isolateRef.id;

      if (isolateId == null) {
        throw Exception('not reachable');
      }

      Directory directory;

      if (uri.scheme.startsWith('package')) {
        // TODO: resolve package directory
        throw UnimplementedError('package');
      } else {
        directory = Directory.fromUri(uri.resolve('.'));
      }

      Future<void> reloader(FileSystemEvent event) async {
        stdout.writeln('Reloading...');

        var result = await service.reloadSources(isolateId);

        if (result.success == true) {
          await service.callServiceExtension('ext.astra.reasemble', isolateId: isolateId);
        }
      }

      var watch = directory
          .watch(events: FileSystemEvent.modify, recursive: true)
          .throttle(Duration(seconds: 1))
          .listen(reloader);
      shutdownCallbacks.add(watch.cancel);
    } else {
      process.stdout.listen(stdout.add);
    }

    var sigint = ProcessSignal.sigint.watch().listen(null);
    sigint.onData((signal) {
      for (var callback in shutdownCallbacks) {
        callback();
      }

      sigint.cancel();
      completer.complete(130);
    });

    return completer.future;
  }

  String createSource(Uri uri, String target) {
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/cli.dart';
import 'package:astra/serve.dart';

import '$uri' as _;

Future<void> main() async {
  ApplicationManager.init();

  await serve(_.$target, 'localhost', 3000);
  print('serving at http://localhost:3000');
}

''';
  }
}

class StdoutLog implements Log {
  @override
  void severe(String message) {
    stdout.writeln(message);
  }

  @override
  void warning(String message) {
    stdout.writeln(message);
  }
}
