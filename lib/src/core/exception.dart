import 'http.dart';
import 'request.dart';
import 'response.dart';
import 'types.dart';

class HTTPException implements Exception {
  const HTTPException(this.status, [this.message]);

  final int status;

  final String? message;

  @override
  String toString() {
    var buffer = StringBuffer(runtimeType)..write('(')..write(status);

    if (message != null) {
      buffer..write(', ')..write(message);
    }

    buffer.write(')');
    return buffer.toString();
  }

  static Response handler(Request request, Object exception, StackTrace stackTrace) {
    var typedException = exception as HTTPException;

    if (typedException.status == 204 || typedException.status == 304) {
      return Response(status: typedException.status);
    }

    return TextResponse(typedException.message ?? '', status: exception.status);
  }
}

Application exception(Application application, Map<Object, ExceptionHandler> handlers) {
  var statusHandlers = <int, ExceptionHandler>{};
  var exceptionHandlers = <Type, ExceptionHandler>{HTTPException: HTTPException.handler};

  for (var statusOrException in handlers.keys) {
    if (statusOrException is int) {
      statusHandlers[statusOrException] = handlers[statusOrException]!;
    } else if (statusOrException is Type) {
      exceptionHandlers[statusOrException] = handlers[statusOrException]!;
    } else {
      throw ArgumentError.value(statusOrException);
    }
  }

  return (Request request, Start start, Send send) async {
    var responseStarted = false;

    void starter({int status = StatusCode.ok, String? reason, List<Header>? headers}) {
      responseStarted = true;
      start(status: status, headers: headers);
    }

    try {
      await application(request, starter, send);
    } catch (error, stackTrace) {
      ExceptionHandler? handler;

      if (error is HTTPException) {
        handler = statusHandlers[error.status];
      }

      handler ??= exceptionHandlers[error.runtimeType];

      if (handler == null) {
        rethrow;
      }

      if (responseStarted) {
        throw StateError('caught handled exception, but response already started');
      }

      var response = await handler(request, error, stackTrace);
      response(request, start, send);
    }
  };
}
