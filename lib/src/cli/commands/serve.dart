import 'dart:convert';
import 'dart:isolate';

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

  String? get target {}

  @override
  Future<int> run() async {
    var rest = argResults!.rest;
    var length = rest.length;

    if (length == 0) {
      usageException('Must specify an package or file to serve.');
    }

    if (length > 1) {
      usageException('Must specify one package or file to serve.');
    }

    var path = toUri(absolute(rest[0])).toString();
    var source = createScript(path, 'application');
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

      print(error);
      print(trace.terse);

      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    exitPort.listen((Object? message) {
      print('exitPort: $message');
      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    isolate.resume(isolate.pauseCapability!);
    return 0;
  }

  String createScript(String path, String symbol) {
    return '''
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/serve.dart';

import '$path' show $symbol;

Future<void> main(List<String> arguments, SendPort sendPort) async {
  await runZoned<Future<void>>(
    () async {
      await serve($symbol, 'localhost', 3000);
    },
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
        sendPort.send(message);
      },
    ),
  );
  throw Exception('hey');
}

''';
  }
}
