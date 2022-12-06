import 'dart:io' show HttpStatus;

import 'package:astra/core.dart';
import 'package:astra/test.dart';
import 'package:test/test.dart';

void main() {
  test('sync handler returns a value to the client', () async {
    Response handler(Request request) {
      return Response.ok('Hello from ${request.requestedUri.path}');
    }

    var client = TestClient(handler);
    var response = await client.get(Uri(path: ''));
    expect(response.statusCode, equals(HttpStatus.ok));
    expect(response.body, equals('Hello from /'));
  });

  test('async handler returns a value to the client', () async {
    Future<Response> handler(Request request) {
      Response callback() {
        return Response.ok('Hello from ${request.requestedUri.path}');
      }

      return Future<Response>(callback);
    }

    var client = TestClient(handler);
    var response = await client.get(Uri(path: ''));
    expect(response.statusCode, equals(HttpStatus.ok));
    expect(response.body, equals('Hello from /'));
  });

  test('thrown error leads to a 500', () async {
    Response handler(Request request) {
      throw UnsupportedError('test');
    }

    var client = TestClient(handler);
    var response = await client.get(Uri(path: ''));
    expect(response.statusCode, equals(HttpStatus.internalServerError));
    expect(response.body, equals('Internal Server Error'));
  });

  test('async error leads to a 500', () async {
    Future<Response> handler(Request request) {
      return Future<Response>.error(UnsupportedError('test'));
    }

    var client = TestClient(handler);
    var response = await client.get(Uri(path: ''));
    expect(response.statusCode, equals(HttpStatus.internalServerError));
    expect(response.body, equals('Internal Server Error'));
  });
}
