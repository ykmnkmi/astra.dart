import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:astra/src/cli/project.dart';
import 'package:astra/src/cli/utils.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_transform/stream_transform.dart';

class ServeCommand extends Command<int> with Project {
  ServeCommand() {
    argParser
      ..addOption('target', abbr: 't')
      ..addFlag('reload', abbr: 'r')
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
    print(Platform.executableArguments);

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

    stdout.write('Running $path\n');

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
    var dataUri = Uri.dataFromString(source, mimeType: 'application/dart', encoding: utf8);

    var shutdownCallbacks = <FutureOr<void> Function()>[];

    var messagePort = ReceivePort();
    var errorPort = ReceivePort();
    var exitPort = ReceivePort();

    shutdownCallbacks
      ..add(messagePort.close)
      ..add(errorPort.close)
      ..add(exitPort.close);

    var isolate = await Isolate.spawnUri(dataUri, <String>[], messagePort.sendPort,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        packageConfig: Uri.file('.dart_tool/package_config.json'),
        paused: true);

    messagePort.listen(stdout.writeln);

    errorPort.listen((Object? message) {
      var list = (message as List<Object?>).cast<String>();
      var error = list[0];
      var stackTrace = list[1];
      var trace = Trace.parse(stackTrace);

      stderr
        ..writeln('error: $error')
        ..writeln('${trace.terse}');

      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    exitPort.listen((Object? message) {
      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    if (hotReload) {
      var isolateID = Service.getIsolateID(isolate);

      if (isolateID == null) {
        throw Exception('don\'t supported');
      }

      var service = await getService();
      shutdownCallbacks.add(service.dispose);

      Directory directory;

      if (uri.scheme.startsWith('package')) {
        // TODO: resolve package directory
        throw UnimplementedError('package');
      } else {
        directory = Directory.fromUri(uri.resolve('.'));
      }

      Future<void> reloader(FileSystemEvent event) async {
        stdout.writeln('Reloading...');

        var result = await service.reloadSources(isolateID);
        stdout.writeln('Reloading success: ${result.success}');
      }

      var watch = directory
          .watch(events: FileSystemEvent.modify, recursive: true)
          .throttle(Duration(seconds: 1))
          .asyncMapSample<void>(reloader)
          .listen(null);
      shutdownCallbacks.add(watch.cancel);
    }

    var sigint = ProcessSignal.sigint.watch().listen(null);
    sigint.onData((signal) {
      for (var callback in shutdownCallbacks) {
        callback();
      }

      sigint.cancel();
    });

    isolate.resume(isolate.pauseCapability!);
    return 0;
  }

  String createSource(Uri uri, String target) {
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/cli.dart';
import 'package:astra/serve.dart';

import '$uri' as application show $target;

Future<void> main() async {
  ApplicationManager.init();

  var handler = await getHandler(application.$target);
  await serve(handler, 'localhost', 3000);
}

''';
  }
}
