import 'dart:io';

import 'package:astra/cli.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await CLIRunner().run(arguments);
  } catch (error, stackTrace) {
    stderr
      ..writeln(error)
      ..writeln(Trace.format(stackTrace));
  }
}
