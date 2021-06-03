import 'dart:async' show FutureOr;
import 'dart:convert' show json, utf8;

import 'package:astra/astra.dart';
import 'package:astra/testing.dart';
import 'package:test/test.dart';

void main() {
  group('response', () {
    test('text', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        final response = Response(content: 'hello world!');
        return response(request, start, send);
      }

      final client = TestClient(application);
      final response = await client.get('/');
      expect(response.body, equals('hello world!'));
    });

    test('bytes', () async {
      final bytes = utf8.encode('xxxxx');

      FutureOr<void> application(Request request, Start start, Send send) {
        final response = Response(content: bytes, contentType: 'image/png');
        return response(request, start, send);
      }

      final client = TestClient(application);
      final response = await client.get('/');
      expect(response.bodyBytes, orderedEquals(bytes));
    });

    test('json null', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        final response = JSONResponse(null);
        return response(request, start, send);
      }

      final client = TestClient(application);
      final response = await client.get('/');
      expect(json.decode(response.body), isNull);
    });

    test('head', () async {
      final application = Response(content: 'hello world!', contentType: ContentTypes.text);
      final client = TestClient(application);
      final response = await client.head('/');
      expect(response.body, equals(''));
    });
  });
}
