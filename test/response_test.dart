import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/test.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('response', () {
    test('text', () async {
      Response handler(Request request) {
        return Response.ok('hello world!');
      }

      var client = TestClient(handler);
      var response = await client.get(Uri(path: ''));
      expect(response.body, 'hello world!');
    });

    test('bytes', () async {
      Response handler(Request request) {
        var headers = <String, String>{HttpHeaders.contentTypeHeader: 'image/png'};
        return Response.ok('xxxxx'.codeUnits, headers: headers);
      }

      var client = TestClient(handler);
      var response = await client.get(Uri(path: ''));
      expect(response.bodyBytes, 'xxxxx'.codeUnits);
    });
  });
}
