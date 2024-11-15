import 'dart:async' show Future, FutureOr;
import 'dart:convert' show Encoding;
import 'dart:typed_data' show Uint8List;

import 'package:shelf/shelf.dart' show Response;
import 'package:shelf_client/src/client_stub.dart'
    if (dart.library.js_interop) 'package:shelf_client/src/js_client.dart'
    if (dart.library.io) 'package:shelf_client/src/io_client.dart';

/// Represents an HTTP client that can perform various HTTP requests.
abstract interface class Client {
  factory Client() {
    return createClient();
  }

  /// Sends an HTTP HEAD request to the specified [url].
  Future<Response> head(Uri url, {Map<String, String>? headers});

  /// Sends an HTTP GET request to the specified [url].
  Future<Response> get(Uri url, {Map<String, String>? headers});

  /// Sends an HTTP POST request to the specified [url].
  Future<Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  /// Sends an HTTP PUT request to the specified [url].
  Future<Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  /// Sends an HTTP PATCH request to the specified [url].
  Future<Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  /// Sends an HTTP DELETE request to the specified [url].
  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  /// Sends an HTTP GET request to the specified [url] and returns the body as
  /// a String.
  Future<String> read(Uri url, {Map<String, String>? headers});

  /// Sends an HTTP GET request to the specified [url] and returns the body as
  /// a [Uint8List].
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers});

  /// {@template astra_client_close}
  /// Closes the client and cleans up any associated resources.
  /// {@endtemplate}
  FutureOr<void> close();
}
