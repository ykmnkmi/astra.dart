// ignore_for_file: avoid_print

import 'dart:convert' show utf8;
import 'dart:io' show HttpStatus;

import 'package:astra/core.dart';
import 'package:stack_trace/stack_trace.dart' show Trace;

const List<Header> headers = <Header>[
  Header('content-length', '12'),
  Header('content-type', 'text/plain'),
];

Future<void> main() async {
  var server = await Server.bind('localhost', 3000);
  print('listening at ${server.url}');

  server.listen((request) async {
    if (request.url.path == '/') {
      request
        ..start(HttpStatus.ok, headers: headers)
        ..send(utf8.encode('hello world!'));

      print(request.url);
      request.headers.raw.forEach(print);
      print('');
    } else {
      request.start(HttpStatus.notFound);
    }

    await request.flush();
    return request.close();
  }, onError: (Object error, StackTrace trace) {
    print(error);
    print(Trace.format(trace, terse: true));
  });
}
