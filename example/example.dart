import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';

Response application(Request request) {
  switch (request.url.path) {
    case '':
      return Response.ok('hello world!');
    case 'readme':
      return Response.ok(File('README.md').openRead());
    case 'error':
      throw Exception('some message');
    default:
      return Response.notFound('Request for "${request.url}"');
  }
}

Handler applicationFactory() {
  void log(String message, [Object? error, StackTrace? stackTrace]) {
    if (error == null) {
      print(message);
    } else {
      print('$message\n$error\n$stackTrace');
    }
  }

  return const Pipeline()
      .addMiddleware(error(debug: true))
      .addMiddleware(logger(log))
      .addHandler(application);
}

Future<void> main() async {
  var handler = applicationFactory();
  var server = await serve(handler, 'localhost', 3000);
  print('serving at http://localhost:${server.port}');
}

// ignore_for_file: avoid_print
