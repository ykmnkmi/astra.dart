// ignore_for_file: avoid_print

import 'dart:convert' show utf8;
import 'dart:io' show HttpServer;

import 'package:stack_trace/stack_trace.dart' show Trace;

Stream<String> numbers(int minimum, int maximum) async* {
  yield '$minimum';
  minimum += 1;

  for (; minimum <= maximum; minimum += 1) {
    await Future<void>.delayed(Duration(milliseconds: 500));
    yield ', $minimum';
  }
}

Future<void> main() async {
  var server = await HttpServer.bind('localhost', 3000);

  server.listen((request) async {
    var response = request.response;

    if (request.uri.path == '/') {
      response.statusCode = 202;
      response.bufferOutput = false;
      await response.addStream(utf8.encoder.bind(numbers(1, 10)));
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
