import 'dart:convert' show Encoding;
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf_client/shelf_client.dart';

abstract mixin class BaseClient implements Client {
  void _checkResponseSuccess(Uri url, Response response) {
    if (response.statusCode < 400) {
      return;
    }

    throw Exception('Request to $url failed with ${response.statusCode} code.');
  }

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) {
    return send(Request('HEAD', url, headers: headers));
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) {
    return send(Request('GET', url, headers: headers));
  }

  @override
  Future<Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return send(
        Request('POST', url, headers: headers, body: body, encoding: encoding));
  }

  @override
  Future<Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return send(
        Request('PUT', url, headers: headers, body: body, encoding: encoding));
  }

  @override
  Future<Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return send(Request('PATCH', url,
        headers: headers, body: body, encoding: encoding));
  }

  @override
  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return send(Request('DELETE', url,
        headers: headers, body: body, encoding: encoding));
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async {
    var response = await get(url, headers: headers);
    _checkResponseSuccess(url, response);
    return response.readAsString();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async {
    var response = await get(url, headers: headers);
    _checkResponseSuccess(url, response);

    Uint8List fold(Uint8List bytes, List<int> chunk) {
      return bytes..addAll(chunk);
    }

    return response.read().fold(Uint8List(0), fold);
  }

  @override
  void close() {}
}
