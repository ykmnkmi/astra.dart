import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:yaml/yaml.dart';

abstract class CLICommand extends Command<int> {
  /// @nodoc
  CLICommand() {
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
      throw Exception('run is not called.');
    }

    return argResults;
  }

  /// @nodoc
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

  /// @nodoc
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

  /// @nodoc
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

    // TODO: update error
    throw Exception('failed to locate ${library.path}');
  }

  bool get verbose {
    return getBoolean('verbose');
  }

  bool getBoolean(String name) {
    return argResults.wasParsed(name);
  }

  int getPositive(String name, [int defaultValue = 0]) {
    var value = argResults[name] as String?;

    if (value == null) {
      return defaultValue;
    }

    var parsed = int.parse(value);

    if (parsed < 0) {
      usageException('$name must be zero or positive');
    }

    return parsed;
  }

  String getString(String name, [String defaultValue = '']) {
    return argResults[name] as String? ?? defaultValue;
  }

  Future<int> handle();

  @override
  Future<int> run() async {
    try {
      return await handle();
    } catch (error, stackTrace) {
      print(error);
      print(Trace.format(stackTrace));
    }

    return 1;
  }
}
