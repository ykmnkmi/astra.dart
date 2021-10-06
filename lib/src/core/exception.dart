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
    var buffer = StringBuffer(runtimeType)
      ..write('(')
      ..write(status);

    if (message != null) {
      buffer
        ..write(', ')
        ..write(message);
    }

    buffer.write(')');
    return '$buffer';
  }

  static Future<Response> handler(
      Request request, Object error, StackTrace stackTrace) {
    var typed = error as HTTPException;
    Response response;

    if (typed.status == 204 || typed.status == 304) {
      response = Response(status: typed.status);
    } else {
      response = TextResponse(typed.message ?? '', status: error.status);
    }

    return Future<Response>.value(response);
  }
}

Application exception(
    Application application, Map<Object, ExceptionHandler> handlers) {
  var statusHandlers = <int, ExceptionHandler>{};
  var exceptionHandlers = <Type, ExceptionHandler>{
    HTTPException: HTTPException.handler
  };

  for (var statusOrException in handlers.keys) {
    if (statusOrException is int) {
      statusHandlers[statusOrException] = handlers[statusOrException]!;
    } else if (statusOrException is Type) {
      exceptionHandlers[statusOrException] = handlers[statusOrException]!;
    } else {
      throw ArgumentError.value(statusOrException);
    }
  }

  return (Request request) async {
    var start = request.start;
    var responseStarted = false;

    request.start = (int status, {String? reason, List<Header>? headers}) {
      responseStarted = true;
      start(status, headers: headers);
    };

    try {
      await application(request);
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
        throw StateError(
            'caught handled exception, but response already started');
      }

      var response = await handler(request, error, stackTrace);
      return response(request);
    }
  };
}
