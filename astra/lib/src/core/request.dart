import 'dart:io' show HttpConnectionInfo;

import 'package:shelf/shelf.dart' show Request;

export 'package:shelf/shelf.dart' show Request;

/// An extension on the [Request] class that provides additional functionality.
extension RequestExtension on Request {
  /// Retrieves information about the client's connection to the server.
  ///
  /// This getter returns information about the client's connection, such as the
  /// remote address and port, or `null` if the socket information is not
  /// available.
  HttpConnectionInfo? get connectionInfo =>
      context['shelf.io.connection_info'] as HttpConnectionInfo?;
}
