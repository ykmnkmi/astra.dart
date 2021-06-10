import 'dart:async' show Completer;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, HttpStatus;

import 'package:astra/astra.dart' show Application, Header;
import 'package:astra/io.dart' show IORequest;
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
    return request(url, (Client client, Uri url) => client.head(url));
  }

  Future<Response> get(String url) {
    return request(url, (Client client, Uri url) => client.get(url));
  }

  Future<Response> post(String url) {
    return request(url, (Client client, Uri url) => client.post(url));
  }

  Future<Response> request(String path, Future<Response> Function(Client client, Uri url) callback) async {
    var server = await HttpServer.bind('localhost', port);
    var responseFuture = callback(client, Uri.http('localhost:$port', path));
    var responseCompleter = Completer<Response>.sync();
    var serverSubscription = server.listen(null);

    serverSubscription.onData((HttpRequest ioRequest) async {
      var ioResponse = ioRequest.response;
      var isRedirectResponse = false;

      void start({int status = HttpStatus.ok, String? reason, List<Header>? headers}) {
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
        await application(IORequest(ioRequest), start, send);

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
