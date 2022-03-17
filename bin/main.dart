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

Handler application() {
  return logRequests().handle(hello);
}

Future<void> main(List<String> arguments, SendPort sendPort) async {
  var handler = await getHandler(application);
  IsolateServer(sendPort, handler, InternetAddress.loopbackIPv4, 3000);
}
