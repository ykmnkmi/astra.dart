// ignore_for_file: avoid_print

import 'dart:io' show File, HttpServer;

import 'package:stack_trace/stack_trace.dart' show Trace;

Future<void> main() async {
  var server = await HttpServer.bind('localhost', 3000);

  server.listen((request) async {
    var response = request.response;

    if (request.uri.path == '/') {
      response.statusCode = 202;
      await response.addStream(File('README.md').openRead());
    } else {
      response.statusCode = 404;
    }

    await response.flush();
    return response.close();
  }, onError: (Object error, StackTrace trace) {
    print(error);
    print(Trace.format(trace, terse: true));
  });
}
