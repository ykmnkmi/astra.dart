import 'dart:async' show FutureOr;
import 'dart:convert' show json, utf8;
import 'dart:io' show Directory, File;

import 'package:astra/astra.dart';
import 'package:astra/testing.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('text response', () async {
    FutureOr<void> application(Request request, Start start, Send send) {
      var response = Response(content: 'hello world!');
      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/');
    client.close();
    expect(response.body, equals('hello world!'));
  });

  test('bytes response', () async {
    var bytes = utf8.encode('xxxxx');

    FutureOr<void> application(Request request, Start start, Send send) {
      var response = Response(content: bytes, contentType: 'image/png');
      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/');
    client.close();
    expect(response.bodyBytes, orderedEquals(bytes));
  });

  test('json null response', () async {
    FutureOr<void> application(Request request, Start start, Send send) {
      var response = JSONResponse(null);
      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/');
    client.close();
    expect(json.decode(response.body), isNull);
  });

  test('redirect response', () async {
    FutureOr<void> application(Request request, Start start, Send send) {
      Response response;

      if (request.url.path == '/') {
        response = TextResponse('hello world!');
      } else {
        response = RedirectResponse(Uri(path: '/'));
      }

      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/redirect');
    client.close();
    expect(response.body, equals('hello world!'));
  });

  test('quoting redirect response', () async {
    FutureOr<void> application(Request request, Start start, Send send) {
      Response response;

      if (request.url.path == Uri.encodeFull('/I ♥ Astra/')) {
        response = TextResponse('hello world!');
      } else {
        response = RedirectResponse(Uri(path: '/I ♥ Astra/'));
      }

      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/redirect');
    client.close();
    expect(response.body, equals('hello world!'));
  });

  test('streaming response', () async {
    Stream<String> numbers(int minimum, int maximum) async* {
      for (var i = minimum; i < maximum + 1; i++) {
        yield '$i';

        if (i != maximum) {
          yield ', ';
        }

        await Future<void>.delayed(Duration.zero);
      }
    }

    FutureOr<void> application(Request request, Start start, Send send) {
      var stream = numbers(1, 5);
      var response = StreamResponse.text(stream);
      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/');
    client.close();
    expect(response.body, equals('1, 2, 3, 4, 5'));
  });

  test('sync streaming response', () async {
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
    client.close();
    expect(response.body, equals('1, 2, 3, 4, 5'));
  });

  test('response headers', () async {
    FutureOr<void> application(Request request, Start start, Send send) {
      var headers = <String, String>{'x-header-1': '123', 'x-header-2': '456'};
      var response = TextResponse('hello world!', headers: headers);
      response.headers.set('x-header-2', '789');
      return response(request, start, send);
    }

    var client = TestClient(application);
    var response = await client.get('/');
    client.close();
    expect(response.headers['x-header-1'], equals('123'));
    expect(response.headers['x-header-2'], equals('789'));
  });

  test('response phrase', () async {
    var client = TestClient(Response(status: StatusCode.noContent));
    var response = await client.get('/');
    expect(response.reasonPhrase, equals(ReasonPhrase.noContent));
    client = TestClient(Response(status: 123));
    response = await client.get('/');
    client.close();
    // TODO: replace 'Status 123' with ''
    expect(response.reasonPhrase, equals('Status 123'));
  });

  test('file response', () async {
    var filePath = path.join(Directory.systemTemp.path, 'xyz');
    var content = utf8.encode('<file content>' * 1000);
    await File(filePath).writeAsBytes(content);
    var client = TestClient(FileResponse(filePath, fileName: 'example.png'));
    var response = await client.get('/');
    client.close();
    var contentDisposition = 'attachment; filename="example.png"';
    expect(response.statusCode, equals(StatusCode.ok));
    expect(response.bodyBytes, orderedEquals(content));
    expect(response.headers[Headers.contentType], equals('image/png'));
    expect(response.headers[Headers.contentDisposition], equals(contentDisposition));
    expect(response.headers, contains(Headers.contentLength));
    expect(response.headers, contains(Headers.lastModified));
  });

  test('file response with directory raises error', () async {
    var client = TestClient(FileResponse(Directory.systemTemp.path, fileName: 'example.png'));

    try {
      await client.get('/');
      client.close();
    } catch (error) {
      expect(error, isA<StateError>().having((error) => error.message, 'message', contains('is not a file')));
    }
  });

  test('file response with missing file raises error', () async {
    var filePath = path.join(Directory.systemTemp.path, '404.txt');
    var client = TestClient(FileResponse(filePath, fileName: '404.txt'));

    try {
      await client.get('/');
      client.close();
    } catch (error) {
      expect(error, isA<StateError>().having((error) => error.message, 'message', contains('does not exist')));
    }
  });

  test('file response with chinese filename', () async {
    var fileName = '你好.txt';
    var content = utf8.encode('file content');
    var filePath = path.join(Directory.systemTemp.path, fileName);
    await File(filePath).writeAsBytes(content);
    var client = TestClient(FileResponse(filePath, fileName: fileName));
    var response = await client.get('/');
    client.close();
    var contentDisposition = 'attachment; filename*=utf-8\'\'%E4%BD%A0%E5%A5%BD.txt';
    expect(response.statusCode, equals(StatusCode.ok));
    expect(response.bodyBytes, orderedEquals(content));
    expect(response.headers[Headers.contentDisposition], equals(contentDisposition));
  });

  test('populate headers', () async {
    var client = TestClient(TextResponse('hi'));
    var response = await client.get('/');
    client.close();
    expect(response.body, equals('hi'));
    expect(response.headers[Headers.contentLength], equals('2'));
    expect(response.headers[Headers.contentType], equals(ContentTypes.text));
  });

  test('head method', () async {
    var application = Response(content: 'hello world!', contentType: ContentTypes.text);
    var client = TestClient(application);
    var response = await client.head('/');
    client.close();
    expect(response.body, equals(''));
  });
}
