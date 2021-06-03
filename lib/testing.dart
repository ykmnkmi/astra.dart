import 'dart:async' show Completer;
import 'dart:io' show HttpStatus;

import 'package:astra/astra.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient, MockClientHandler;

class TestClient extends MockClient {
  static MockClientHandler mockApplication(Application application) {
    return (http.Request httpRequest) {
      var method = httpRequest.method;
      var headers = <Header>[];
      var bytes = httpRequest.bodyBytes;

      httpRequest.headers.forEach((String name, String values) {
        for (var value in values.split(',')) {
          headers.add(Header(name, value));
        }
      });

      var request = TestRequest(method: method, headers: Headers(raw: headers), bytes: bytes);
      var sendCompleter = Completer<void>();

      var responseStatus = HttpStatus.ok;
      var responseHeaders = <String, String>{};

      void start({int status = HttpStatus.ok, List<Header> headers = const <Header>[], bool buffer = true}) {
        responseStatus = status;

        for (var header in headers) {
          if (responseHeaders.containsKey(header.name)) {
            responseHeaders[header.name] = responseHeaders[header.name]! + ', ${header.value}';
          } else {
            responseHeaders[header.name] = header.value;
          }
        }
      }

      var responseBytes = <int>[];

      void send({List<int> bytes = const <int>[], bool end = false}) {
        responseBytes.addAll(bytes);

        if (end) {
          sendCompleter.complete();
        }
      }

      return Future<void>.sync(() => application(request, start, send))
          .then<void>((_) => sendCompleter.future)
          .then<http.Response>((_) => http.Response.bytes(responseBytes, responseStatus, headers: responseHeaders));
    };
  }

  TestClient(this.application) : super(mockApplication(application));

  final Application application;
}

class TestRequest extends Request {
  TestRequest({this.method = 'GET', Headers? headers, this.bytes = const <int>[]}) : headers = headers ?? Headers();

  @override
  final Headers headers;

  @override
  final String method;

  final List<int> bytes;

  @override
  Uri get url {
    throw UnimplementedError();
  }

  @override
  Future<DataMessage> receive() {
    return Future<DataMessage>.value(DataMessage(bytes, end: true));
  }
}
