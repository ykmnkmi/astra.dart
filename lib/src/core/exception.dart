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
}

class ExceptionMiddleware {
  ExceptionMiddleware(this.application, Map<Object, ExceptionHandler> handlers)
      : statusHandlers = <int, ExceptionHandler>{},
        exceptionHandlers = <Type, ExceptionHandler>{} {
    exceptionHandlers[HTTPException] = httpException;

    for (var statusOrException in handlers.keys) {
      addExceptionHandler(statusOrException, handlers[statusOrException]!);
    }
  }

  final Application application;

  final Map<int, ExceptionHandler> statusHandlers;

  final Map<Type, ExceptionHandler> exceptionHandlers;

  void addExceptionHandler(Object statusOrException, ExceptionHandler handler) {
    if (statusOrException is int) {
      statusHandlers[statusOrException] = handler;
    } else if (statusOrException is Type) {
      exceptionHandlers[statusOrException] = handler;
    } else {
      throw ArgumentError.value(statusOrException);
    }
  }

  Future<void> call(Request request, Start start, Send send) async {
    var responseStarted = false;

    void starter({int status = StatusCodes.ok, String? reason, List<Header>? headers}) {
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
  }

  static Response httpException(Request request, Object exception, StackTrace stackTrace) {
    var typedException = exception as HTTPException;

    if (typedException.status == 204 || typedException.status == 304) {
      return Response(status: typedException.status);
    }

    return TextResponse(typedException.message ?? '', status: exception.status);
  }
}
