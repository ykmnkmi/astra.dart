import 'dart:async';

import 'package:shelf/shelf.dart';

/// Signature of [HttpError] handler.
typedef HttpErrorHandler = FutureOr<Response> Function(
    Request request, Object error, StackTrace stackTrace);

/// HTTP error that occurred while handling a request.
class HttpError extends Error {
  HttpError(this.status, [this.message]);

  /// Error status code.
  final int status;

  /// Error message.
  final String? message;

  @override
  String toString() {
    var buffer = StringBuffer('HttpError(')..write(status);

    if (message != null) {
      buffer
        ..write(', ')
        ..write(message);
    }

    buffer.write(')');
    return buffer.toString();
  }
}
