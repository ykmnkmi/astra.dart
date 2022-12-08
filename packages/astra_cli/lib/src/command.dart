import 'dart:io' show Directory, File;
import 'dart:isolate' show Isolate;

import 'package:args/args.dart' show ArgResults;
import 'package:args/command_runner.dart' show Command;
import 'package:astra_cli/src/extension.dart';
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
      // application
      ..addSeparator('Application options:')
      ..addOption('target',
          abbr: 't', help: 'Application target.', valueHelp: 'application')
      ..addOption('target-path',
          help: 'Application target location.\n'
              'Must be within application root folder.',
          valueHelp: 'lib/[package].dart')
      ..addOption('directory',
          abbr: 'C', help: 'Application root folder.', valueHelp: '.')
      ..addMultiOption('define',
          abbr: 'D',
          help: 'Define an environment declaration.',
          valueHelp: 'key=value')
      ..addFlag('verbose',
          abbr: 'v', help: 'Print detailed logging.', negatable: false);
  }

  late final String target = getString('target') ?? 'application';

  late final String targetPath =
      getString('target-path') ?? join(directoryPath, 'lib', '$package.dart');

  late final String directoryPath = getString('directory') ?? '.';

  late final bool verbose = getBoolean('verbose') ?? false;

  late final List<String> defineList =
      getStringList('define').map<String>(normalize).toList();

  @override
  ArgResults get argResults {
    var argResults = super.argResults;

    if (argResults == null) {
      throw CliException('Run is not called');
    }

    return argResults;
  }

  Directory? _cachedWorkingDirectory;

  Directory get workingDirectory {
    var directory = _cachedWorkingDirectory;

    if (directory != null) {
      return directory;
    }

    directory = Directory(normalize(directoryPath));

    if (!directory.existsSync()) {
      throw CliException('Directory not found: $directoryPath');
    }

    _cachedWorkingDirectory = directory;
    return directory;
  }

  File? _cachedPubspecFile;

  File get pubspecFile {
    var file = _cachedPubspecFile;

    if (file != null) {
      return file;
    }

    file = File(join(workingDirectory.path, 'pubspec.yaml'));

    if (!file.existsSync()) {
      throw CliException('${workingDirectory.path} is not package');
    }

    _cachedPubspecFile = file;
    return file;
  }

  Map<String, Object?>? _cachedPubspec;

  Map<String, Object?> get pubspec {
    var spec = _cachedPubspec;

    if (spec != null) {
      return spec;
    }

    var file = pubspecFile;

    if (!file.existsSync()) {
      throw CliException('Failed to locate ${file.path}');
    }

    var content = file.readAsStringSync();
    var yaml = loadYaml(content) as Map<Object?, Object?>;
    spec = yaml.cast<String, Object?>();
    _cachedPubspec = spec;
    return spec;
  }

  String? _cachedPackage;

  String get package {
    return _cachedPackage ??= pubspec['name'] as String;
  }

  File? _cachedTargetFile;

  File get targetFile {
    var target = _cachedTargetFile;

    if (target != null) {
      return target;
    }

    target = File(targetPath);

    if (!target.existsSync()) {
      throw CliException('Failed to locate $targetPath');
    }

    _cachedTargetFile = target;
    return target;
  }

  Future<String> renderTemplate(String name, Map<String, String> data) async {
    var templateUri = Uri(
      scheme: 'package',
      path: 'astra_cli/src/templates/$name.template',
    );

    var templateResolvedUri = await Isolate.resolvePackageUri(templateUri);

    if (templateResolvedUri == null) {
      throw CliException('Serve template uri not resolved');
    }

    var template = await File.fromUri(templateResolvedUri).readAsString();

    String replace(Match match) {
      var variable = match.group(1);

      if (variable == null) {
        throw StateError("Template variable '$variable' not found");
      }

      return data[variable]!;
    }

    return template.replaceAllMapped(RegExp('__([A-Z][0-9A-Z]*)__'), replace);
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
