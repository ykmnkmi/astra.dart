import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

Future<Response> application(Request request) async {
  print("'${request.url}'");

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
