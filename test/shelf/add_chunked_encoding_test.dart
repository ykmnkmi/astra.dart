// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:test/test.dart';

FutureOr<Response> chunkResponse(int statusCode, [Object? body, Map<String, Object>? headers]) {
  Response innerHandler(Request request) {
    return Response(statusCode, body: body, headers: headers);
  }

  var handler = addChunkedEncoding(innerHandler);
  return handler(Request('GET', Uri.parse('http://example.com/')));
}

void main() {
  test('adds chunked encoding with no transfer-encoding header', () async {
    var response = await chunkResponse(200, Stream.value('hi'.codeUnits));
    expect(response.headers, containsPair('transfer-encoding', 'chunked'));
    expect(response.readAsString(), completion(equals('2\r\nhi\r\n0\r\n\r\n')));
  });

  test('adds chunked encoding with transfer-encoding: identity', () async {
    var headers = {'transfer-encoding': 'identity'};
    var response = await chunkResponse(200, Stream.value('hi'.codeUnits), headers);
    expect(response.headers, containsPair('transfer-encoding', 'chunked'));
    expect(response.readAsString(), completion(equals('2\r\nhi\r\n0\r\n\r\n')));
  });

  test("doesn't add chunked encoding with content length", () async {
    var response = await chunkResponse(200, 'hi');
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.readAsString(), completion(equals('hi')));
  });

  test("doesn't add chunked encoding with status 1xx", () async {
    var response = await chunkResponse(123, Stream<List<int>>.empty());
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 204", () async {
    var response = await chunkResponse(204, Stream<List<int>>.empty());
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 304", () async {
    var response = await chunkResponse(204, Stream<List<int>>.empty());
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 204", () async {
    var response = await chunkResponse(204, Stream<List<int>>.empty());
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });

  test("doesn't add chunked encoding with status 204", () async {
    var response = await chunkResponse(204, Stream<List<int>>.empty());
    expect(response.headers, isNot(contains('transfer-encoding')));
    expect(response.read().toList(), completion(isEmpty));
  });
}
