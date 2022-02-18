import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';

typedef YAML = Map<Object?, Object?>;

typedef JSON = Map<String, Object?>;

mixin Project {
  Directory get directory {
    return Directory.current.absolute;
  }

  File get specificationFile {
    return File.fromUri(directory.uri.resolve('pubspec.yaml'));
  }

  Map<String, Object?>? cachedSpecification;

  Map<String, Object?> get specification {
    var specification = cachedSpecification;

    if (specification != null) {
      return specification;
    }

    var file = specificationFile;

    if (file.existsSync()) {
      var content = file.readAsStringSync();
      var yaml = loadYaml(content) as Map<Object?, Object?>;
      return yaml.cast<String, Object?>();
    }

    throw Exception('Failed to locate pubspec.yaml in \'${directory.path}\'');
  }

  String? get package {
    return specification['name'] as String?;
  }

  String? get library {
    return package;
  }
}

class AstraCommandRunner extends CommandRunner<int> {
  AstraCommandRunner() : super('astra', 'Astra CLI tool for managing Astra Shelf applications.') {
    argParser.addFlag('version', negatable: false, help: 'Print Astra CLI tool version.');

    addCommand(ServeCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      var result = parse(args);
      return await runCommand(result) ?? 0;
    } on UsageException catch (error) {
      stderr.write('${error.message}\n\n${error.usage}\n');
      return 64;
    }
  }
}

class ServeCommand extends Command<int> with Project {
  @override
  String get name {
    return 'serve';
  }

  @override
  String get description {
    return 'Serve an file.';
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
    return '$invocation [options] file[:application]';
  }

  @override
  Future<int> run() async {
    var rest = argResults!.rest;
    var length = rest.length;

    if (length == 0) {
      usageException('Must specify an file to serve.');
    }

    if (length > 1) {
      usageException('Must specify one file to serve.');
    }

    var uri = Uri.file(rest[0]);
    var path = uri.path;
    print(path);
    var source = createScript(path, 'application');
    var dataUri = Uri.dataFromString(source, mimeType: 'application/dart', encoding: utf8);
    // var dataUri = Uri.parse('data:application/dart;charset=utf-8,$source');

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
      print(message);
    });

    exitPort.listen((Object? message) {
      messagePort.close();
      errorPort.close();
      exitPort.close();
    });

    isolate.resume(isolate.pauseCapability!);
    return 0;
  }

  String createScript(String path, String symbol) {
    return '''
import 'dart:io';
import 'dart:isolate';

import 'package:astra/serve.dart';

import '$path' show $symbol;

Future<void> main(List<String> arguments, SendPort? sendPort) async {
  sendPort?.send('starting...');
  await serve($symbol, 'localhost', 3000);
  sendPort?.send('started');
}

''';
  }
}
