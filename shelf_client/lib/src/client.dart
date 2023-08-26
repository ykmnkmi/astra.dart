import 'dart:async' show Future;
import 'dart:convert' show Encoding;
import 'dart:typed_data' show Uint8List;

import 'package:shelf/shelf.dart' show Request, Response;

/// Represents an HTTP client that can perform various HTTP requests.
abstract interface class Client {
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

  /// Sends the given [request] and returns the response.
  Future<Response> send(Request request);

  /// {@template Client.close}
  /// Closes the client and cleans up any associated resources.
  /// {@endtemplate}
  void close();
}
