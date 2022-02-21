import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:astra/src/cli/commands/serve.dart';

typedef YAML = Map<Object?, Object?>;

typedef JSON = Map<String, Object?>;

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
