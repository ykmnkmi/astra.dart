import 'dart:io' show HttpConnectionInfo, X509Certificate;

import 'package:shelf/shelf.dart' show Request;

export 'package:shelf/shelf.dart' show Request;

/// An extension on the [Request] class that provides additional functionality.
extension RequestExtension on Request {
  /// Retrieves information about the client's connection to the server.
  ///
  /// This getter returns information about the client's connection, such as the
  /// remote address and port, or `null` if the socket information is not
  /// available.
  HttpConnectionInfo? get connectionInfo {
    return context['shelf.io.connection_info'] as HttpConnectionInfo?;
  }

  /// The client certificate of the client making the request.
  ///
  /// This value is `null` if the connection is not a secure TLS or SSL
  /// connection, or if the server does not request a client certificate,
  /// or if the client does not provide one.
  X509Certificate? get certificate {
    return context['astra.server.certificate'] as X509Certificate?;
  }
}
