import 'dart:io';

import 'package:astra/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await CliRunner().run(arguments);
  Process.killPid(pid);
}
