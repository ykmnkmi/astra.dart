import 'dart:io' show HttpClient, HttpClientResponse;

import 'package:shelf/shelf.dart' show Request, Response;
import 'package:shelf_client/src/base_client.dart';

class IOClient extends BaseClient {
  IOClient([HttpClient? inner]) : _inner = inner ?? HttpClient();

  HttpClient? _inner;

  @override
  Future<Response> send(Request request) async {
    var client = _inner;

    if (client == null) {
      throw Exception('Client is already closed.');
    }

    var ioRequest = await client.openUrl(request.method, request.requestedUri);
    ioRequest.contentLength = request.contentLength ?? -1;

    request.headers.forEach((name, value) {
      ioRequest.headers.set(name, value);
    });

    var ioResponse = await request.read().pipe(ioRequest) as HttpClientResponse;
    var headers = <String, List<String>>{};

    ioResponse.headers.forEach((name, values) {
      headers[name] = values;
    });

    return Response(ioResponse.statusCode,
        body: ioResponse, headers: headers, encoding: request.encoding);
  }

  @override
  void close() {
    if (_inner case var inner?) {
      inner.close();
      _inner = null;
    }
  }
}
