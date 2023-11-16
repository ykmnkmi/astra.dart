import 'dart:convert';

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/servers/h11.dart';
import 'package:shelf_client/io_client.dart';

class TestClient extends IOClient {
  TestClient({
    this.host = 'localhost',
    this.port = 80,
  }) : _server = H11Server(host, port);

  final String host;

  final int port;

  final Server _server;

  Future<void> handle(Handler handler) async {
    await _server.handle(handler);
  }

  Future<void> mount(Application application) async {
    await _server.mount(application);
  }

  @override
  Request makeRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    url = url.replace(
      scheme: url.scheme.isEmpty ? 'http' : url.scheme,
      host: url.host.isEmpty ? host : url.host,
      port: url.port == 0 ? port : url.port,
    );

    return Request(
      method,
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

  @override
  Future<void> close() async {
    await _server.close();
    await super.close();
  }
}
