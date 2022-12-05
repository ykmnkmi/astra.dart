import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:astra_cli/src/command.dart';
import 'package:astra_cli/src/commands/serve.dart';

class CliRunner extends CommandRunner<int> {
  CliRunner() : super('astra', 'Astra/Shelf CLI.') {
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
    } on CliException catch (error) {
      stderr.writeln(error.message);
      return 1;
    }
  }
}
