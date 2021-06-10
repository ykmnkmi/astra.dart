// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'dart:io';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
  final bytes = utf8.encode('hello world!');

  await for (final request in server) {
    print(request.uri);

    final response = request.response;

    if (request.uri.path != '/') {
      response
        ..statusCode = 404
        ..close();
      continue;
    }

    response
      ..contentLength = bytes.length
      ..add(bytes)
      ..close();
  }
}
