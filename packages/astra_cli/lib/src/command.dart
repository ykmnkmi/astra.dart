import 'dart:io' show Directory, File;
import 'dart:isolate' show Isolate;

import 'package:args/args.dart' show ArgResults;
import 'package:args/command_runner.dart' show Command;
import 'package:astra_cli/src/extension.dart';
import 'package:path/path.dart' show absolute, isWithin, join, normalize;
import 'package:pubspec/pubspec.dart';

/// A exception thrown by command line interfaces.
class CliException implements Exception {
  CliException(this.message);

  /// A message describing the CLI error.
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

  late final String targetPath = normalize(
      getString('target-path') ?? join(directoryPath, 'lib', '$package.dart'));

  late final String directoryPath =
      normalize(absolute(getString('directory') ?? '.'));

  late final bool verbose = getBoolean('verbose') ?? false;

  late final List<String> defineList = getStringList('define').toList();

  @override
  ArgResults get argResults {
    var argResults = super.argResults;

    if (argResults == null) {
      throw CliException('Run is not called');
    }

    return argResults;
  }

  late final Directory directory = Directory(directoryPath);

  late final File pubspecFile = File(join(directory.path, 'pubspec.yaml'));

  late final PubSpec pubspec =
      PubSpec.fromYamlString(pubspecFile.readAsStringSync());

  late final String package = pubspec.name!;

  late final File targetFile = File(targetPath);

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

      return data[variable] as String;
    }

    return template.replaceAllMapped(RegExp('__([A-Z][0-9A-Z]*)__'), replace);
  }

  Future<void> check() async {
    if (!directory.existsSync()) {
      throw CliException('Directory not exists: $directoryPath');
    }

    if (!pubspecFile.existsSync()) {
      throw CliException("'pubspec.yaml' not found in $directoryPath");
    }

    if (!isWithin(directoryPath, targetPath)) {
      throw CliException('Target path must be within package directory');
    }

    if (!targetFile.existsSync()) {
      throw CliException('Target file not found: $targetPath');
    }
  }

  Future<int> handle();

  Future<void> cleanup() async {}

  @override
  Future<int> run() async {
    await check();

    try {
      return await handle();
    } finally {
      await cleanup();
    }
  }
}
