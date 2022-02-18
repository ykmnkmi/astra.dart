import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';
import 'package:l/l.dart';

Response application(Request request) {
  switch (request.url.path) {
    case '':
      return Response.ok('hello world!');
    case 'readme':
      return Response.ok(File('README.md').openRead());
    case 'error':
      throw Exception('some message');
    default:
      return Response.ok('Request for "${request.url}"');
  }
}

void log(String message, bool isError) {
  if (isError) {
    l << message;
  } else {
    l < message;
  }
}

Future<void> main() async {
  var pipeline = Pipeline().addMiddleware(logger(log)).addMiddleware(error(debug: true));
  var addHandler = pipeline.addHandler(application);
  var server = await serve(addHandler, 'localhost', 3000);
  print('serving at http://localhost:${server.port}');
}

// ignore_for_file: avoid_print
