import 'dart:async' show Future;
import 'dart:convert' show Encoding;
import 'dart:io' show HttpClient, SecurityContext;

import 'package:astra/core.dart';
import 'package:astra/serve.dart';

// ignore: implementation_imports
import 'package:shelf_client/src/io_client.dart';

class TestClient extends IOClient {
  TestClient(
    this.handler, {
    this.host = 'localhost',
    this.port = 0,
    this.context,
  })  : scheme = context == null ? 'http' : 'https',
        super(HttpClient(context: context));

  final Handler handler;

  final String scheme;

  final String host;

  final int port;

  final SecurityContext? context;

  Future<Response> withServer(
    Uri url,
    Future<Response> Function(Uri url) callback,
  ) async {
    var server = await handler.serve(host, port, securityContext: context);

    url = url.replace(
      scheme: url.scheme.isEmpty ? scheme : url.scheme,
      host: url.host.isEmpty ? host : url.host,
      port: port == 0 ? server.port : url.port,
    );

    var response = await callback(url);
    await server.close();
    return response;
  }

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) {
    return withServer(url, (url) {
      return super.head(url, headers: headers);
    });
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) {
    return withServer(url, (url) {
      return super.get(url, headers: headers);
    });
  }

  @override
  Future<Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return withServer(url, (url) {
      return super.post(
        url,
        headers: headers,
        body: body,
        encoding: encoding,
      );
    });
  }

  @override
  Future<Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return withServer(url, (url) {
      return super.put(
        url,
        headers: headers,
        body: body,
        encoding: encoding,
      );
    });
  }

  @override
  Future<Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return withServer(url, (url) {
      return super.patch(
        url,
        headers: headers,
        body: body,
        encoding: encoding,
      );
    });
  }

  @override
  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return withServer(url, (url) {
      return super.delete(
        url,
        headers: headers,
        body: body,
        encoding: encoding,
      );
    });
  }
}
