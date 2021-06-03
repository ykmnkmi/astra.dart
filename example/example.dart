// ignore_for_file: avoid_print

import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/controllers.dart';
import 'package:astra/io.dart';

FutureOr<void> exmaple(Request request, Start start, Send send) {
  if (request.url.path != '/') {
    start(status: 404);
    return null;
  }

  // final response = TextResponse('hello');
  // return response(request, start, send);
  throw Exception('rieee!');
}

Future<void> main() async {
  final server = await IOServer.bind('localhost', 3000);
  final application = ServerErrorMiddleware(exmaple, debug: true);
  server.mount(application);
  print('serving at http://localhost:3000');
}
