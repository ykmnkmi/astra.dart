// ignore_for_file: avoid_print

import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/io.dart';

FutureOr<void> example(Request request, Start start, Send send) {
  Response response;

  if (request.url.path == '/') {
    response = TextResponse(' ');
  } else {
    response = Response.notFound();
  }

  return response(request, start, send);
}

Future<void> main() async {
  var server = await IOServer.bind('localhost', 3000);
  server.mount(log(error(example)));
  print('serving at http://localhost:3000');
}
