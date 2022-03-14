import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:astra/src/cli/path.dart';
import 'package:yaml/yaml.dart';

abstract class AstraCommand extends Command<int> {
  AstraCommand() {
    argParser
      ..addSeparator('Common options:')
      ..addOption('directory', abbr: 'd', help: 'Run this in the directory', valueHelp: 'dir');
  }

  @override
  ArgResults get argResults {
    return super.argResults!;
  }

  Directory? cachedDirectory;

  Directory get directory {
    var directory = cachedDirectory;

    if (directory != null) {
      return directory;
    }

    var path = argResults['directory'] as String?;
    directory = path == null ? Directory.current : Directory(path);

    if (directory.existsSync()) {
      cachedDirectory = directory;
      return directory;
    }

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

    throw Exception('failed to locate ${libraryFile.path}');
  }
}
