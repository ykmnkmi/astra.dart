/// Astra testing utilities.
library astra.testing;

import 'dart:async' show Completer, StreamIterator;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, HttpStatus;

import 'package:astra/astra.dart' show Application, DataMessage, Header, Headers, MutableHeaders, Request;
import 'package:http/http.dart' show Client, Response;

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

  Future<Response> request(String path, Future<Response> Function(Client client, Uri url) callback) async {
    final server = await HttpServer.bind('localhost', port);
    final responseFuture = callback(client, Uri.http('localhost:$port', path));
    final responseCompleter = Completer<Response>.sync();
    final serverSubscription = server.listen(null);

    serverSubscription.onData((ioRequest) async {
      final ioResponse = ioRequest.response;
      var isRedirectResponse = false;

      void start({int status = HttpStatus.ok, String? reason, List<Header>? headers}) {
        ioResponse.statusCode = status;

        if (headers != null) {
          for (final header in headers) {
            ioResponse.headers.set(header.name, header.value);

            if (header.name == HttpHeaders.locationHeader) {
              isRedirectResponse = true;
            }
          }
        }
      }

      Future<void> send({List<int> bytes = const <int>[], bool flush = false, bool end = false}) async {
        ioResponse.add(bytes);

        if (flush) {
          await ioResponse.flush();
        }

        if (end) {
          await ioResponse.close();
        }
      }

      try {
        final request = TestRequest(ioRequest);
        await application(request, start, send);

        if (isRedirectResponse) {
          return;
        }

        responseCompleter.complete(responseFuture);
      } catch (error, stackTrace) {
        responseCompleter.completeError(error, stackTrace);
      }
    });

    try {
      return await responseCompleter.future;
    } finally {
      await serverSubscription.cancel();
      await server.close();
    }
  }
}

class TestHeaders implements Headers {
  TestHeaders(this.headers);

  final HttpHeaders headers;

  @override
  List<Header> get raw {
    final raw = <Header>[];

    headers.forEach((String name, List<String> values) {
      for (final value in values) {
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
  TestRequest(this.request, {Headers? headers})
      : iterable = StreamIterator<List<int>>(request),
        headers = headers ?? TestHeaders(request.headers);

  final HttpRequest request;

  final StreamIterator<List<int>> iterable;

  @override
  final Headers headers;

  @override
  String get method {
    return request.method;
  }

  @override
  Uri get url {
    return request.uri;
  }

  @override
  Future<DataMessage> receive() async {
    if (await iterable.moveNext()) {
      return DataMessage(iterable.current);
    }

    return DataMessage.empty(end: true);
  }
}
