import 'package:args/command_runner.dart';

class AstraCommandRunner extends CommandRunner<int> {
  AstraCommandRunner() : super('astra', 'Astra CLI tool for managing Astra Shelf applications.') {
    argParser.addFlag('version', negatable: false, help: 'Print Astra CLI tool version.');

    addCommand(RunCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      var result = parse(args);
      return await runCommand(result) ?? 0;
    } on UsageException {
      printUsage();
      return 64;
    }
  }
}

class RunCommand extends Command<int> {
  @override
  String get name {
    return 'run';
  }

  @override
  String get description {
    return 'Run an file or package';
  }

  @override
  String get invocation {
    var parents = <String>[name];

    for (var command = parent; command != null; command = command.parent) {
      parents.add(command.name);
    }

    parents.add(runner!.executableName);

    var invocation = parents.reversed.join(' ');
    return '$invocation <file-or-package>';
  }

  @override
  Future<int> run() async {
    throw UnimplementedError();
  }
}
