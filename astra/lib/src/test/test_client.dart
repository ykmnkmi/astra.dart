import 'dart:async' show Future;
import 'dart:convert' show Encoding;
import 'dart:io' show HttpClient, SecurityContext;

import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/response.dart';
import 'package:astra/src/serve/serve.dart';
import 'package:shelf_client/io_client.dart';

class TestClient extends IOClient {
  TestClient(
    this.handler, {
    this.host = 'localhost',
    this.port = 0,
    this.context,
  })  : scheme = context == null ? 'http' : 'https',
        super(httpClient: HttpClient(context: context));

  final Handler handler;

  final String scheme;

  final String host;

  final int port;

  final SecurityContext? context;

  Future<Response> withServer(
    Uri url,
    Future<Response> Function(Uri url) callback,
  ) async {
    SecurityContextFactory? securityContextFactory;

    if (context case var context?) {
      securityContextFactory = () => context;
    }

    var server = await handler.serve(host, port,
        securityContextFactory: securityContextFactory);

    url = url.replace(
        scheme: url.scheme.isEmpty ? scheme : url.scheme,
        host: url.host.isEmpty ? host : url.host,
        port: port == 0 ? server.url.port : url.port);

    var response = await callback(url);
    await server.close();
    return response;
  }

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) {
    Future<Response> callback(Uri url) {
      return super.head(url, headers: headers);
    }

    return withServer(url, callback);
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) {
    Future<Response> callback(Uri url) {
      return super.get(url, headers: headers);
    }

    return withServer(url, callback);
  }

  @override
  Future<Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    Future<Response> callback(Uri url) {
      return super.post(url, headers: headers, body: body, encoding: encoding);
    }

    return withServer(url, callback);
  }

  @override
  Future<Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    Future<Response> callback(Uri url) {
      return super.put(url, headers: headers, body: body, encoding: encoding);
    }

    return withServer(url, callback);
  }

  @override
  Future<Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    Future<Response> callback(Uri url) {
      return super.patch(url, headers: headers, body: body, encoding: encoding);
    }

    return withServer(url, callback);
  }

  @override
  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    Future<Response> callback(Uri url) {
      return super
          .delete(url, headers: headers, body: body, encoding: encoding);
    }

    return withServer(url, callback);
  }
}
