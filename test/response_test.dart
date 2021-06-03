import 'dart:async' show FutureOr;
import 'dart:convert' show json, utf8;

import 'package:astra/astra.dart';
import 'package:astra/testing.dart';
import 'package:test/test.dart';

void main() {
  group('response', () {
    test('text', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        var response = Response(content: 'hello world!');
        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/');
      expect(response.body, equals('hello world!'));
    });

    test('bytes', () async {
      var bytes = utf8.encode('xxxxx');

      FutureOr<void> application(Request request, Start start, Send send) {
        var response = Response(content: bytes, contentType: 'image/png');
        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/');
      expect(response.bodyBytes, orderedEquals(bytes));
    });

    test('json null', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        var response = JSONResponse(null);
        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/');
      expect(json.decode(response.body), isNull);
    });

    test('redirect', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        const path = '/';

        Response response;

        if (request.url.path == path) {
          response = TextResponse('hello world!');
        } else {
          response = RedirectResponse(Uri(path: path));
        }

        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/redirect');
      expect(response.body, equals('hello world!'));
    });

    test('quoting redirect', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        const path = '/I ♥ Astra/';

        Response response;

        if (request.url.path == Uri.encodeFull(path)) {
          response = TextResponse('hello world!');
        } else {
          response = RedirectResponse(Uri(path: path));
        }

        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/redirect');
      expect(response.body, equals('hello world!'));
    });

    test('streaming', () async {
      Stream<String> numbers(int minimum, int maximum) async* {
        for (var i = minimum; i < maximum + 1; i++) {
          yield '$i';

          if (i != maximum) {
            yield ', ';
          }

          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      FutureOr<void> application(Request request, Start start, Send send) {
        var stream = numbers(1, 5);
        var response = StreamResponse.text(stream);
        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/');
      expect(response.body, equals('1, 2, 3, 4, 5'));
    });

    test('sync streaming', () async {
      Stream<String> numbers(int minimum, int maximum) async* {
        for (var i = minimum; i < maximum + 1; i++) {
          yield '$i';

          if (i != maximum) {
            yield ', ';
          }
        }
      }

      FutureOr<void> application(Request request, Start start, Send send) {
        var stream = numbers(1, 5);
        var response = StreamResponse.text(stream);
        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/');
      expect(response.body, equals('1, 2, 3, 4, 5'));
    });

    test('headers', () async {
      FutureOr<void> application(Request request, Start start, Send send) {
        var headers = <String, String>{'x-header-1': '123', 'x-header-2': '456'};
        var response = TextResponse('hello world!', headers: headers);
        response.headers.set('x-header-2', '789');
        return response(request, start, send);
      }

      var client = TestClient(application);
      var response = await client.get('/');
      expect(response.headers['x-header-1'], equals('123'));
      expect(response.headers['x-header-2'], equals('789'));
    });

    test('response phrase', () async {
      var client = TestClient(Response(status: StatusCodes.noContent));
      var response = await client.get('/');
      expect(response.reasonPhrase, equals(ReasonPhrases.noContent));

      client = TestClient(Response(status: 123));
      response = await client.get('/');
      // TODO: match ''
      expect(response.reasonPhrase, equals('Status 123'));
    });

    test('populate headers', () async {
      const text = 'hi';

      var client = TestClient(TextResponse(text));
      var response = await client.get('/');
      expect(response.body, equals(text));
      expect(response.headers[Headers.contentLength], equals('${text.length}'));
      expect(response.headers[Headers.contentType], equals(ContentTypes.text));
    });

    test('head', () async {
      var application = Response(content: 'hello world!', contentType: ContentTypes.text);
      var client = TestClient(application);
      var response = await client.head('/');
      expect(response.body, equals(''));
    });
  });
}
