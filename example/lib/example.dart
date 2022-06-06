import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';

Future<Response> application(Request request) async {
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

class Hello extends Application {
  const Hello();

  @override
  Handler get entryPoint {
    return application.use(error(debug: true));
  }

  @override
  void reload() {
    log('reload');
  }

  @override
  Future<void> close() async {
    log('closed');
  }
}
