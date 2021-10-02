/// Astra testing utilities.
library astra.testing;

import 'dart:async' show Completer, StreamIterator;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, HttpStatus;

import 'package:astra/astra.dart' show Application, DataMessage, Header, Headers, MutableHeaders, Request, Send, Start;
import 'package:http/http.dart' show Client, Response;

typedef TestClientCallback = Future<Response> Function(Client client, Uri url);

class TestClient {
  TestClient(this.application, {this.port = 3000}) : client = Client();

  final Application application;

  final Client client;

  final int port;

  void close() {
    client.close();
  }

  Future<Response> head(String url) {
    return request(url, (client, url) => client.head(url));
  }

  Future<Response> get(String url) {
    return request(url, (client, url) => client.get(url));
  }

  Future<Response> post(String url) {
    return request(url, (client, url) => client.post(url));
  }

  Future<Response> request(String path, TestClientCallback callback) {
    return HttpServer.bind('localhost', port).then<Response>((server) {
      var responseFuture = callback(client, Uri.http('localhost:$port', path));
      var responseCompleter = Completer<Response>.sync();
      var serverSubscription = server.listen(null);

      serverSubscription.onData((ioRequest) {
        var request = TestRequest(ioRequest);
        var ioResponse = ioRequest.response;
        var isRedirectResponse = false;

        request.start = ({int status = HttpStatus.ok, String? reason, List<Header>? headers}) {
          ioResponse.statusCode = status;

          if (headers != null) {
            for (var header in headers) {
              ioResponse.headers.set(header.name, header.value);

              if (header.name == HttpHeaders.locationHeader) {
                isRedirectResponse = true;
              }
            }
          }
        };

        request.send = ({List<int>? bytes, bool flush = false, bool end = false}) {
          if (bytes != null) {
            ioResponse.add(bytes);
          }

          if (flush) {
            if (end) {
              return ioResponse.flush().then<void>((void _) => ioResponse.close());
            }

            return ioResponse.flush();
          }

          if (end) {
            return ioResponse.close();
          }
        };

        Future<void>.value(application(request)).then<void>((void _) {
          if (isRedirectResponse) {
            return;
          }

          responseCompleter.complete(responseFuture);
        }).catchError(responseCompleter.completeError);
      });

      return responseCompleter.future
          .whenComplete(() => serverSubscription.cancel().then<void>((void _) => server.close()));
    });
  }
}

class TestHeaders implements Headers {
  TestHeaders(this.headers);

  final HttpHeaders headers;

  @override
  List<Header> get raw {
    var raw = <Header>[];

    headers.forEach((String name, List<String> values) {
      for (var value in values) {
        raw.add(Header(name, value));
      }
    });

    return raw;
  }

  @override
  @pragma('vm:prefer-inline')
  String? operator [](String name) {
    return get(name);
  }

  @override
  bool contains(String name) {
    return headers[name] != null;
  }

  @override
  String? get(String name) {
    return headers.value(name);
  }

  @override
  List<String> getAll(String name) {
    return headers[name] ?? <String>[];
  }

  @override
  MutableHeaders toMutable() {
    throw UnimplementedError();
  }
}

class TestRequest extends Request {
  TestRequest(this.request, {Headers? headers}) : headers = headers ?? TestHeaders(request.headers);

  final HttpRequest request;

  StreamIterator<List<int>>? iterator;

  @override
  final Headers headers;

  @override
  late Start start;

  @override
  late Send send;

  @override
  String get method {
    return request.method;
  }

  @override
  Uri get url {
    return request.uri;
  }

  @override
  Stream<List<int>> get stream {
    if (streamConsumed) {
      // TODO: update error
      throw Exception('stream consumed');
    }

    streamConsumed = true;
    return request;
  }

  @override
  Future<List<int>> receive() {
    var iterator = this.iterator ??= StreamIterator<List<int>>(stream);
    return iterator.moveNext().then<List<int>>((moved) => moved ? iterator.current : <int>[]);
  }
}
