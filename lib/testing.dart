import 'dart:async' show Completer, FutureOr, StreamSubscription;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, HttpStatus;

import 'package:astra/astra.dart' show Application, Header;
import 'package:astra/io.dart' show IORequest;
import 'package:http/http.dart' show Client, Response;
import 'package:http_multi_server/http_multi_server.dart' show HttpMultiServer;

class TestClient {
  TestClient(this.application, {this.port = 3000});

  final Application application;

  final int port;

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
    var server = await HttpMultiServer.loopback(port);
    var client = Client();
    var future = callback(client, Uri.http('localhost:$port', path));
    var completer = Completer<Response>();
    var subscription = server.listen(null);

    subscription.onData((HttpRequest request) async {
      var response = request.response;
      var location = false;

      void start({int status = HttpStatus.ok, String? reason, List<Header>? headers, bool buffer = false}) {
        response.statusCode = status;

        if (headers != null) {
          for (final header in headers) {
            response.headers.set(header.name, header.value);

            if (header.name == HttpHeaders.locationHeader) {
              location = true;
            }
          }
        }

        response.bufferOutput = buffer;
      }

      Future<void> send({List<int> bytes = const <int>[], bool end = false}) async {
        response.add(bytes);

        if (end) {
          if (!response.bufferOutput) {
            await response.flush();
          }

          response.close();
        }
      }

      await application(IORequest(request), start, send);

      if (location) {
        return;
      }

      completer.complete(future);
    });

    final response = await completer.future;
    client.close();
    await subscription.cancel();
    await server.close();
    return response;
  }
}
