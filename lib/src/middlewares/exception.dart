import 'dart:html';

import 'package:astra/core.dart';

Middleware exception({Map<Object, ErrorHandler>? handlers, Map<String, String>? headers}) {
  var statusHandlers = <int, HttpErrorHandler>{};
  var exceptionHandlers = <bool Function(Object), ErrorHandler>{};

  handlers?.forEach((statusOrException, handler) {
    if (statusOrException is int) {
      statusHandlers[statusOrException] = handler;
    } else if (statusOrException is bool Function(Object)) {
      exceptionHandlers[statusOrException] = handler;
    } else {
      throw ArgumentError.value(statusOrException, 'handlers', 'Keys must be int or Type');
    }
  });

  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (error, stackTrace) {
        HttpErrorHandler? handler;

        if (error is HttpError) {
          handler = statusHandlers[error.status];
        }

        if (handler == null) {
          for (var entry in exceptionHandlers.entries) {
            if (entry.key(error)) {
              handler = entry.value;
              break;
            }
          }
        }

        if (handler == null) {
          if (error is HttpError) {
            if (error.status == HttpStatus.noContent || error.status == HttpStatus.notModified) {
              return Response(error.status, headers: headers);
            }

            return Response(error.status, headers: headers);
          }

          rethrow;
        }

        return handler(request, error, stackTrace);
      }
    };
  };
}
