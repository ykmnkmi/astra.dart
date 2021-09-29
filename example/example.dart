// ignore_for_file: avoid_print

import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/io.dart';

FutureOr<void> application(Connection connection) {
  Response response;

  if (connection.url.path == '/') {
    response = TextResponse('hello world!');
  } else {
    response = Response.notFound();
  }

  return response(connection);
}

Future<void> main() async {
  var server = await IOServer.bind('localhost', 3000);
  server.mount(log(error(application)));
  print('serving at http://localhost:3000');
}
