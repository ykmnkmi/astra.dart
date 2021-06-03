import 'dart:io' show HttpRequest, HttpServer;

import 'package:astra/astra.dart' show Application;
import 'package:astra/io.dart' show handle;
import 'package:http/http.dart' show Client, Response;
import 'package:http_multi_server/http_multi_server.dart' show HttpMultiServer;

class TestClient {
  TestClient(this.application, {this.port = 3000});

  final Application application;

  final int port;

  Future<Response> head(String url) {
    return request('path', (Client client, Uri url) => client.head(url));
  }

  Future<Response> get(String url) {
    return request('path', (Client client, Uri url) => client.get(url));
  }

  Future<Response> post(String url) {
    return request('path', (Client client, Uri url) => client.post(url));
  }

  Future<Response> request(String path, Future<Response> Function(Client client, Uri url) callback) {
    return HttpMultiServer.loopback(port).then<Response>((HttpServer server) {
      var client = Client();
      var future = callback(client, Uri.http('localhost:$port', path));
      return server.first.then<Response>((HttpRequest request) {
        handle(request, application);
        return future.then<Response>((Response response) {
          client.close();
          return server.close().then((_) => response);
        });
      });
    });
  }
}
