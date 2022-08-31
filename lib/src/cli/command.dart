import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

/// A exception thrown by command line interfaces.
class CliException implements Exception {
  CliException(this.message);

  final String message;

  @override
  String toString() {
    return 'CliException: $message';
  }
}

/// A command line interface command.
abstract class CliCommand extends Command<int> {
  CliCommand() {
    argParser
      ..addSeparator('Common options:')
      ..addOption('directory', //
          abbr: 'd',
          help: 'Run this in the directory.',
          valueHelp: 'path')
      ..addFlag('verbose', //
          abbr: 'v',
          negatable: false,
          help: 'Output more informational messages.')
      ..addFlag('version', //
          negatable: false,
          help: 'Prints tool version.');
  }

  @override
  ArgResults get argResults {
    var argResults = super.argResults;

    if (argResults == null) {
      throw CliException('run is not called.');
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

    throw CliException('directory not found: $path');
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

    throw CliException('failed to locate ${file.path}');
  }

  String get package {
    return specification['name'] as String;
  }

  File? cachedLibrary;

  File get library {
    var library = cachedLibrary;

    if (library != null) {
      return library;
    }

    library = File(join(directory.path, 'lib', '$package.dart'));

    if (library.existsSync()) {
      cachedLibrary = library;
      return library;
    }

    throw CliException('failed to locate ${library.path}');
  }

  bool get verbose {
    return getBoolean('verbose');
  }

  bool get version {
    return getBoolean('version');
  }

  bool getBoolean(String name) {
    return argResults[name] as bool? ?? false;
  }

  int? getInteger(String name) {
    var value = argResults[name] as String?;

    if (value == null) {
      return null;
    }

    var parsed = int.parse(value);

    if (parsed < 0) {
      usageException('$name must be zero or positive');
    }

    return parsed;
  }

  String? getString(String name) {
    return argResults[name] as String?;
  }

  Future<void> cleanup() async {}

  Future<int> handle();

  @override
  Future<int> run() async {
    try {
      return await handle();
    } finally {
      await cleanup();
    }
  }
}
