import 'dart:io' show Directory, File;

import 'package:args/args.dart' show ArgResults;
import 'package:args/command_runner.dart' show Command;
import 'package:path/path.dart' show join, normalize;
import 'package:yaml/yaml.dart' show loadYaml;

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
      ..addFlag('verbose', negatable: false)
      ..addOption('directory', abbr: 'C')
      ..addMultiOption('define', abbr: 'D', splitCommas: false);
  }

  @override
  ArgResults get argResults {
    var argResults = super.argResults;

    if (argResults == null) {
      throw CliException('Run is not called');
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

    throw CliException('Directory not found: $path');
  }

  File? cachedPubspecFile;

  File get pubspecFile {
    return cachedPubspecFile ??= File(join(directory.path, 'pubspec.yaml'));
  }

  Map<String, Object?>? cachedPubspec;

  Map<String, Object?> get pubspec {
    var pubspec = cachedPubspec;

    if (pubspec != null) {
      return pubspec;
    }

    var file = pubspecFile;

    if (file.existsSync()) {
      var content = file.readAsStringSync();
      var yaml = loadYaml(content) as Map<Object?, Object?>;
      pubspec = yaml.cast<String, Object?>();
      cachedPubspec = pubspec;
      return pubspec;
    }

    throw CliException('Failed to locate ${file.path}');
  }

  String? cachedPackage;

  String get package {
    return cachedPackage ??= pubspec['name'] as String;
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

    throw CliException('Failed to locate ${library.path}');
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
      usageException('$name must be zero or positive integer');
    }

    return parsed;
  }

  String? getString(String name) {
    return argResults[name] as String?;
  }

  List<String> getStringList(String name) {
    return argResults[name] as List<String>;
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
