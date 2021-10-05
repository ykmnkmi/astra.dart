/// Astra testing utilities.
library astra.testing;

import 'dart:async' show Completer;
import 'dart:io' show HttpHeaders, HttpServer, HttpStatus;

import 'package:astra/core.dart' show Application, Header;
import 'package:astra/io.dart' show IORequest;
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

  Future<Response> request(String path, TestClientCallback callback) async {
    var server = await HttpServer.bind('localhost', port);

    var responseFuture = callback(client, Uri.http('localhost:$port', path));
    var responseCompleter = Completer<Response>.sync();
    var serverSubscription = server.listen(null);

    serverSubscription.onData((ioRequest) async {
      var ioResponse = ioRequest.response;
      var isRedirectResponse = false;

      void start(
          {int status = HttpStatus.ok, String? reason, List<Header>? headers}) {
        ioResponse.statusCode = status;

        if (headers != null) {
          for (var header in headers) {
            ioResponse.headers.set(header.name, header.value);

            if (header.name == HttpHeaders.locationHeader) {
              isRedirectResponse = true;
            }
          }
        }
      }

      Future<void> send(
          {List<int>? bytes, bool flush = false, bool end = false}) async {
        if (bytes != null) {
          ioResponse.add(bytes);
        }

        if (flush) {
          await ioResponse.flush();
        }

        if (end) {
          await ioResponse.close();
        }
      }

      var request = IORequest(ioRequest, start, send);

      try {
        await application(request);

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
