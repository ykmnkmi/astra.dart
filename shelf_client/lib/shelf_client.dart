import 'dart:async' show Future;
import 'dart:convert' show Encoding;
import 'dart:typed_data' show Uint8List;

import 'package:shelf/shelf.dart' show Request, Response;
import 'package:shelf_client/src/io_client.dart';

abstract interface class Client {
  factory Client() {
    return IOClient();
  }

  Future<Response> head(Uri url, {Map<String, String>? headers});

  Future<Response> get(Uri url, {Map<String, String>? headers});

  Future<Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  Future<Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  Future<Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  Future<String> read(Uri url, {Map<String, String>? headers});

  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers});

  Future<Response> send(Request request);

  void close();
}
