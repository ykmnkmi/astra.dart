import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

abstract class AstraCommand extends Command<int> {
  AstraCommand() {
    argParser
      ..addSeparator('Common options:')
      ..addOption('directory', //
          abbr: 'd',
          help: 'Run this in the directory.',
          valueHelp: 'path')
      ..addFlag('verbose', //
          abbr: 'v',
          negatable: false,
          help: 'Output more informational messages.');
  }

  @override
  ArgResults get argResults {
    var argResults = super.argResults;

    if (argResults == null) {
      // TODO: update error
      throw StateError('run is not called.');
    }

    return argResults;
  }

  Directory? cachedDirectory;

  Directory get directory {
    var directory = cachedDirectory;

    if (directory != null) {
      return directory;
    }

    var path = argResults['directory'] as String?;
    directory = path == null ? Directory.current : Directory(normalize(path));

    if (directory.existsSync()) {
      cachedDirectory = directory;
      return directory;
    }

    // TODO: update error
    throw Exception('directory not found: $path');
  }

  File get specificationFile {
    return File(join(directory.path, 'pubspec.yaml'));
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

    // TODO: update error
    throw Exception('failed to locate ${file.path}');
  }

  String get package {
    return specification['name'] as String;
  }

  File? cachedLibraryFile;

  File get libraryFile {
    var libraryFile = cachedLibraryFile;

    if (libraryFile != null) {
      return libraryFile;
    }

    libraryFile = File(join(directory.path, 'lib', '$package.dart'));

    if (libraryFile.existsSync()) {
      cachedLibraryFile = libraryFile;
      return libraryFile;
    }

    // TODO: update error
    throw Exception('failed to locate ${libraryFile.path}');
  }

  bool get verbose {
    return wasParsed('verbose');
  }

  bool wasParsed(String name) {
    return argResults.wasParsed(name);
  }
}
