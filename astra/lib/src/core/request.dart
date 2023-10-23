import 'dart:io' show HttpConnectionInfo;

import 'package:shelf/shelf.dart' show Request;

export 'package:shelf/shelf.dart' show Request;

/// An extension on the [Request] class.
extension RequestExtension on Request {
  /// Information about the client connection.
  ///
  /// Returns `null` if the socket is not available.
  HttpConnectionInfo? get connectionInfo {
    return context['shelf.io.connection_info'] as HttpConnectionInfo?;
  }
}
