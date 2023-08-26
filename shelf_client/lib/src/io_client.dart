import 'dart:io' show HttpClient;

import 'package:shelf/shelf.dart' show Pipeline, Request, Response;
import 'package:shelf_client/src/base_client.dart';
import 'package:shelf_client/src/client.dart';

/// A `dart:io`-based HTTP [Client].
class IOClient extends BaseClient {
  IOClient({HttpClient? httpClient, Pipeline? pipeline})
      : _pipeline = pipeline,
        _client = httpClient ?? HttpClient();

  final Pipeline? _pipeline;

  /// The underlying `dart:io` HTTP client.
  HttpClient? _client;

  @override
  Future<Response> send(Request request) async {
    var client = _client;

    if (client == null) {
      throw Exception('Client is already closed.');
    }

    Future<Response> handler(Request request) async {
      var ioRequest = await client.openUrl(
        request.method,
        request.requestedUri,
      );

      ioRequest.contentLength = request.contentLength ?? -1;

      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      await ioRequest.addStream(request.read());

      var ioResponse = await ioRequest.close();
      var headers = <String, List<String>>{};

      ioResponse.headers.forEach((name, values) {
        headers[name] = <String>[for (var value in values) value.trimRight()];
      });

      return Response(
        ioResponse.statusCode,
        body: ioResponse,
        headers: headers,
        encoding: request.encoding,
      );
    }

    if (_pipeline case var pipeline?) {
      return await pipeline.addHandler(handler)(request);
    }

    return await handler(request);
  }

  /// {@macro Client.close}
  ///
  /// Terminates all active connections.
  @override
  void close() {
    if (_client case var client?) {
      client.close();
      _client = null;
    }
  }
}
