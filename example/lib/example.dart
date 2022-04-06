import 'dart:async';
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

const Example example = Example();

class Example extends Application {
  const Example();

  @override
  Handler get entryPoint => logRequests().handle(handler);

  Future<Response> handler(Request request) async {
    return Response.ok('hello world!');
  }

  @override
  Future<void> prepare() async {
    print('- prepare');
  }

  @override
  Future<void> onClose() async {
    print('- closing');
  }

  @override
  void onReload() {
    print('- reloading');
  }
}
