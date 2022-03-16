import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:astra/serve.dart';

Response hello(Request request) {
  switch (request.url.path) {
    case '':
      return Response.ok('hello world!');
    case 'readme':
      return Response.ok(File('README.md').openRead());
    case 'error':
      throw Exception('some message');
    default:
      return Response.notFound(null);
  }
}

Handler application(String name) {
  return logRequests().handle(hello);
}

Future<void> startServer(String name) async {
  await serve(application(name), 'localhost', 3000, shared: true);
  print('$name: serving at http://localhost:3000');
}

Future<void> main() async {
  await startServer('isolate/0');

  for (var i = 1; i < Platform.numberOfProcessors; i += 1) {
    await Isolate.spawn(startServer, 'isolate/$i');
  }
}
