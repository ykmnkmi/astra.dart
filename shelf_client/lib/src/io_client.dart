import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:shelf/shelf.dart' show Pipeline, Request, Response;
import 'package:shelf_client/src/base_client.dart';
import 'package:shelf_client/src/client.dart';

/// Create an [IOClient].
Client createClient({Pipeline? pipeline}) {
  return IOClient(pipeline: pipeline);
}

/// A `dart:io`-based HTTP [Client].
class IOClient extends BaseClient {
  IOClient({HttpClient? httpClient, Pipeline? pipeline})
      : _pipeline = pipeline,
        _client = httpClient ?? HttpClient();

  /// The underlying [Pipeline] used to handle requests.
  final Pipeline? _pipeline;

  /// The underlying `dart:io` HTTP client.
  HttpClient? _client;

  @override
  Request makeRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return Request(
      method,
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

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
      request.headers.forEach(ioRequest.headers.set);
      await ioRequest.addStream(request.read());

      var ioResponse = await ioRequest.close();
      var headers = <String, List<String>>{};

      void setHeaders(String name, List<String> values) {
        headers[name] = <String>[
          for (var value in values) value.trimRight(),
        ];
      }

      ioResponse.headers.forEach(setHeaders);

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

  /// {@macro astra_client_close}
  ///
  /// Terminates all active connections.
  @override
  Future<void> close() async {
    if (_client case var client?) {
      client.close();
      _client = null;
    }
  }
}
