import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:astra/src/cli/project.dart';
import 'package:path/path.dart';
import 'package:stack_trace/stack_trace.dart';

class ServeCommand extends Command<int> with Project {
  ServeCommand() {
    argParser.addOption('target', abbr: 't');
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

  @override
  ArgResults get argResults {
    return super.argResults!;
  }

  String get target {
    return argResults['target'] as String? ?? 'application';
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

    if (FileSystemEntity.isFileSync(path)) {
      path = Uri.file(absolute(path)).toString();
    } else {
      if (!path.startsWith('package:')) {
        path = 'package:$path';
      }

      if (!path.endsWith('.dart')) {
        path = '$path.dart';
      }
    }

    var source = createScript(path, target);
    var dataUri = Uri.dataFromString(source, mimeType: 'application/dart', encoding: utf8);

    var messagePort = ReceivePort();
    var errorPort = ReceivePort();
    var exitPort = ReceivePort();

    var isolate = await Isolate.spawnUri(dataUri, <String>[], messagePort.sendPort,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        packageConfig: Uri.file('.dart_tool/package_config.json'),
        paused: true);

    messagePort.listen(print);

    errorPort.listen((Object? message) {
      var list = (message as List<Object?>).cast<String>();
      var error = list[0];
      var stackTrace = list[1];
      var trace = Trace.parse(stackTrace);

      print('error: $error');
      print(trace.terse);

      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    exitPort.listen((Object? message) {
      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    isolate.resume(isolate.pauseCapability!);
    return 0;
  }

  String createScript(String path, String target) {
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/cli.dart';
import 'package:astra/serve.dart';

import '$path' as application show $target;

Future<void> main(List<String> arguments, SendPort sendPort) async {
  var handler = await getHandler(application.$target);
  await serve(handler, 'localhost', 3000);
}

''';
  }
}
