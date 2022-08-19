// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  late H11Server server;

  setUp(() async {
    try {
      server = await H11Server.bind(InternetAddress.loopbackIPv6, 0);
    } on SocketException {
      server = await H11Server.bind(InternetAddress.loopbackIPv4, 0);
    }
  });

  tearDown(server.close);

  test('serves HTTP requests with the mounted handler', () async {
    await server.mount(syncHandler.asApplication());
    expect(http.read(server.url), completion(equals('Hello from /')));
  });

  test('Handles malformed requests gracefully.', () async {
    await server.mount(syncHandler.asApplication());

    var url = Uri.parse('${server.url}/%D0%C2%BD%A8%CE%C4%BC%FE%BC%D0.zip');
    var response = await http.get(url);
    expect(response.statusCode, 400);
    expect(response.body, 'Bad Request');
  });

  test('delays HTTP requests until a handler is mounted', () async {
    expect(http.read(server.url), completion(equals('Hello from /')));
    await Future<void>.delayed(Duration.zero);
    await server.mount(asyncHandler.asApplication());
  });

  test('disallows more than one handler from being mounted', () async {
    await server.mount(Application());
    expect(() => server.mount(Application()), throwsStateError);
    expect(() => server.mount(Application()), throwsStateError);
  });
}
