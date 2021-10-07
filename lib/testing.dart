/// Astra testing utilities.
library astra.testing;

import 'dart:async' show Completer;
import 'dart:io' show HttpHeaders;

import 'package:astra/core.dart' show Application, Header, Server;
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
    var server = await Server.bind('localhost', port);
    var future = callback(client, Uri.http('localhost:$port', path));
    var completer = Completer<Response>.sync();
    var subscription = server.listen((request) async {
      var start = request.start;
      var isRedirectResponse = false;

      request.start =
          (int status, {List<Header>? headers, bool buffer = true}) {
        if (headers != null) {
          for (var header in headers) {
            if (header.name == HttpHeaders.locationHeader) {
              isRedirectResponse = true;
              break;
            }
          }
        }

        start(status, headers: headers, buffer: buffer);
      };

      try {
        await application(request);

        if (isRedirectResponse) {
          return;
        }

        completer.complete(future);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
      await server.close();
    }
  }
}
