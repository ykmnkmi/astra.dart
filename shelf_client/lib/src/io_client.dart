import 'dart:async' show Future, FutureOr;
import 'dart:io' show HttpClient;

import 'package:shelf/shelf.dart' show Pipeline, Request, Response;
import 'package:shelf_client/src/base_client.dart';
import 'package:shelf_client/src/client.dart';

/// Create an [IOClient].
Client createClient({Pipeline? pipeline}) {
  return IOClient(pipeline: pipeline);
}

/// A `dart:io`-based HTTP [Client].
base class IOClient extends BaseClient {
  IOClient({HttpClient? httpClient, Pipeline? pipeline})
      : _pipeline = pipeline,
        _client = httpClient ?? HttpClient();

  /// The underlying [Pipeline] used to handle requests.
  final Pipeline? _pipeline;

  /// The underlying `dart:io` [HttpClient].
  HttpClient? _client;

  @override
  Future<Response> send(Request request) async {
    var client = _client;

    if (client == null) {
      throw StateError('Client is already closed.');
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
        headers[name] = List<String>.of(values);
      }

      ioResponse.headers.forEach(setHeaders);

      return Response(
        ioResponse.statusCode,
        body: ioResponse,
        headers: headers,
        encoding: request.encoding,
      );
    }

    FutureOr<Response> Function(Request) handle;

    if (_pipeline case var pipeline?) {
      handle = pipeline.addHandler(handler);
    } else {
      handle = handler;
    }

    return await handle(request);
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
