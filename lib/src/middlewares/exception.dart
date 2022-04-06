import 'package:astra/core.dart';

Middleware exception(Map<Object, ErrorHandler> handlers, {Map<String, Object>? headers}) {
  var statusHandlers = <int, ErrorHandler>{};
  var exceptionHandlers = <bool Function(Object), ErrorHandler>{};

  for (var entry in handlers.entries) {
    var statusOrException = entry.key;

    if (statusOrException is int) {
      statusHandlers[statusOrException] = entry.value;
    } else if (statusOrException is bool Function(Object)) {
      exceptionHandlers[statusOrException] = entry.value;
    } else {
      throw ArgumentError.value(statusOrException, 'handlers', 'Keys must be int or Type');
    }
  }

  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (error, stackTrace) {
        ErrorHandler? handler;

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
          rethrow;
        }

        return handler(request, error, stackTrace);
      }
    };
  };
}
