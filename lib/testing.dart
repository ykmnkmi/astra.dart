import 'package:astra/astra.dart' show Application;
import 'package:astra/io.dart' show handle;
import 'package:http/http.dart' show Client, Response;
import 'package:http_multi_server/http_multi_server.dart' show HttpMultiServer;

class TestClient {
  TestClient(this.application, {this.port = 3000});

  final Application application;

  final int port;

  Future<Response> get(String url) {
    return request('path', (Client client, Uri url) => client.get(url));
  }

  Future<Response> head(String url) {
    return request('path', (Client client, Uri url) => client.head(url));
  }

  Future<Response> request(String path, Future<Response> Function(Client client, Uri url) callback) async {
    var server = await HttpMultiServer.loopback(port);
    var client = Client();

    var future = callback(client, Uri.http('localhost:$port', path));
    var request = await server.first;
    handle(request, application);
    var response = await future;

    client.close();
    await server.close();

    return response;
  }
}
