import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';

class Hello extends Application {
  int counter = 0;

  @override
  Response call(Request request) {
    counter += 1;

    switch (request.url.path) {
      case '':
        return Response.ok('counter: $counter!');
      case 'readme':
        return Response.ok(File('README.md').openRead());
      case 'error':
        throw Exception('some message');
      default:
        return Response.notFound('Request for "${request.url}"');
    }
  }

  @override
  void reassemble() {
    counter = 0;
  }
}

Handler application() {
  return logRequests().handle(Hello());
}
