import 'dart:io';

import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 8080, isolates: 0);

  var signals = ProcessSignal.sigint.watch();
  await signals.first;
  await server.close();
}
