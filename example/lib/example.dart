import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

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

const Hello hello = Hello();

class Hello {
  const Hello();

  Future<Response> call(Request request) async {
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
}
