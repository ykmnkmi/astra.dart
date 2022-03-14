import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:astra/src/cli/commands/serve.dart';

class AstraCommandRunner extends CommandRunner<int> {
  AstraCommandRunner() : super('astra', 'Astra CLI tool for managing Astra Shelf applications.') {
    addCommand(ServeCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await runCommand(parse(args)) ?? 0;
    } on UsageException catch (error) {
      stderr
        ..writeln(error.message)
        ..writeln()
        ..writeln(error.usage);

      return 64;
    }
  }
}
