import 'dart:convert' show Encoding;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/serve/server.dart';
import 'package:shelf_client/io_client.dart';

/// A test client for making HTTP requests to a server.
class TestClient extends IOClient {
  /// Creates instance of [TestClient].
  TestClient({
    this.host = 'localhost',
    this.port = 8282,
  })  : assert(host.isNotEmpty, 'host cannot be empty'),
        assert(port != 0, 'port cannot be 0.');

  Server? _server;

  /// The host that the underlying server is listening on.
  final String host;

  /// The port that the underlying server is listening on.
  final int port;

  /// Mounts [Handler] to this client.
  Future<void> handle(Handler handler) async {
    _server = await Server.bind(handler, host, port);
  }

  /// Mounts [Application] to this client.
  Future<void> mount(Application application) async {
    _server = await ApplicationServer.bind(application, host, port);
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
        host: url.host.isEmpty ? _server?.url.host : host,
        port: url.port == 0 ? _server?.url.port : port);

    return Request(method, url, //
        headers: headers,
        body: body,
        encoding: encoding);
  }

  @override
  Future<void> close() async {
    if (_server case var server?) {
      await server.close();
    }

    await super.close();
  }
}
