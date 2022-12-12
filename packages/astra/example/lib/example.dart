import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

Application get application => Example();

class Example extends Application {
  int count = 0;

  @override
  Handler get entryPoint {
    return (Request request) async {
      count += 1;

      switch (request.url.path) {
        case '':
          return Response.ok('hello world!');
        case 'count':
          return Response.ok('count: $count');
        case 'readme':
          return Response.ok(File('README.md').openRead());
        case 'error':
          throw Exception('some message');
        default:
          return Response.notFound('Request for "${request.url}"');
      }
    };
  }

  @override
  Future<void> prepare() async {
    print('preparing ...');
    // ...
  }

  @override
  Future<void> reload() async {
    print('reloading ...');
    count = 0;
    // ...
  }

  @override
  Future<void> close() async {
    print('closing ...');
    // ...
  }
}
