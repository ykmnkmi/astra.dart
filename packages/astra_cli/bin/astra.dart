import 'dart:io';

import 'package:astra_cli/astra_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await CliRunner().run(arguments);
}
