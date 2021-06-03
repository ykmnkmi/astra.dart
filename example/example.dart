// ignore_for_file: avoid_print

import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/controllers.dart';
import 'package:astra/io.dart';

FutureOr<void> example(Request request, Start start, Send send) {
  var response = Response(status: 404);
  return response(request, start, send);
}

Future<void> main() async {
  final server = await IOServer.bind('localhost', 3000);
  final application = ServerErrorMiddleware(example, debug: true);
  server.mount(application);
  print('serving at http://localhost:3000');
}
