import 'dart:io';

import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 8080, isolates: 2);
  print('Serving at ${server.url}, press CTRL + C to exit.');
  await ProcessSignal.sigint.watch().first;
  await server.close();
}
