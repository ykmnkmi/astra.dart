import 'dart:async';

import 'package:shelf/shelf.dart';

typedef ErrorHandler = FutureOr<Response> Function(
    Request request, Object error, StackTrace stackTrace);

class HTTPException implements Exception {
  const HTTPException(this.status, [this.message]);

  final int status;

  final String? message;

  @override
  String toString() {
    var buffer = StringBuffer('HTTPException(')..write(status);

    if (message != null) {
      buffer
        ..write(', ')
        ..write(message);
    }

    buffer.write(')');
    return buffer.toString();
  }
}

Middleware exception(Map<Object, ErrorHandler> handlers, {Map<String, Object>? headers}) {
  var statusHandlers = <int, ErrorHandler>{};
  var exceptionHandlers = <bool Function(Object), ErrorHandler>{};

  for (var statusOrException in handlers.keys) {
    if (statusOrException is int) {
      statusHandlers[statusOrException] = handlers[statusOrException]!;
    } else if (statusOrException is bool Function(Object)) {
      exceptionHandlers[statusOrException] = handlers[statusOrException]!;
    } else {
      throw ArgumentError.value(statusOrException, 'handlers', 'Keys must be int or Type');
    }
  }

  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (error) {
        ErrorHandler? handler;

        if (error is HTTPException) {
          handler = statusHandlers[error.status];
        } else {
          for (var entry in exceptionHandlers.entries) {
            if (entry.key(error)) {
              handler = entry.value;
            }
          }
        }

        if (handler == null && error is HTTPException) {
          return Response(error.status, headers: headers, body: error.message);
        }

        rethrow;
      }
    };
  };
}
