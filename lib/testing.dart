import 'dart:async' show Completer;
import 'dart:io' show HttpHeaders, HttpRequest, HttpStatus;

import 'package:astra/astra.dart' show Application, Header;
import 'package:astra/io.dart' show IORequest;
import 'package:http/http.dart' show Client, Response;
import 'package:http_multi_server/http_multi_server.dart' show HttpMultiServer;

class TestClient {
  TestClient(this.application, {this.port = 3000}) : client = Client();

  final Application application;

  final int port;

  final Client client;

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
    var server = await HttpMultiServer.loopback(port, shared: true);
    var responseFuture = callback(client, Uri.http('localhost:$port', path));
    var responseCompleter = Completer<Response>();
    var serverSubscription = server.listen(null);

    serverSubscription.onData((HttpRequest ioRequest) async {
      var ioResponse = ioRequest.response;
      var isRedirectResponse = false;

      void start({int status = HttpStatus.ok, String? reason, List<Header>? headers, bool buffer = false}) {
        ioResponse.statusCode = status;

        if (headers != null) {
          for (final header in headers) {
            ioResponse.headers.set(header.name, header.value);

            if (header.name == HttpHeaders.locationHeader) {
              isRedirectResponse = true;
            }
          }
        }

        ioResponse.bufferOutput = buffer;
      }

      Future<void> send({List<int> bytes = const <int>[], bool end = false}) async {
        ioResponse.add(bytes);

        if (end) {
          if (!ioResponse.bufferOutput) {
            await ioResponse.flush();
          }

          ioResponse.close();
        }
      }

      await application(IORequest(ioRequest), start, send);

      if (isRedirectResponse) {
        return;
      }

      responseCompleter.complete(responseFuture);
    });

    final response = await responseCompleter.future;
    client.close();
    await serverSubscription.cancel();
    await server.close();
    return response;
  }
}
