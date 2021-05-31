import 'dart:async' show FutureOr;

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
    final buffer = StringBuffer(runtimeType)..write('(')..write(status);

    if (message != null) {
      buffer..write(', ')..write(message);
    }

    buffer.write(')');
    return buffer.toString();
  }
}

class ExceptionMiddleware {
  ExceptionMiddleware(
    this.application, {
    Map<Object, ExceptionHandler>? handlers,
    this.debug = false,
  })  : statusHandlers = <int, ExceptionHandler>{},
        exceptionHandlers = <Type, ExceptionHandler>{} {
    exceptionHandlers[HTTPException] = httpException;

    if (handlers != null) {
      for (final statusOrException in handlers.keys) {
        addExceptionHandler(statusOrException, handlers[statusOrException]!);
      }
    }
  }

  final Application application;

  final Map<int, ExceptionHandler> statusHandlers;

  final Map<Type, ExceptionHandler> exceptionHandlers;

  final bool debug;

  void addExceptionHandler(Object statusOrException, ExceptionHandler handler) {
    if (statusOrException is int) {
      statusHandlers[statusOrException] = handler;
    } else if (statusOrException is Type) {
      exceptionHandlers[statusOrException] = handler;
    } else {
      throw ArgumentError.value(statusOrException);
    }
  }

  FutureOr<void> call(Request request, Start start, Respond respond) {
    var responseStarted = false;

    void starter(int status, [List<Header> headers = const <Header>[]]) {
      responseStarted = true;
      start(status, headers);
    }

    FutureOr<void> run() {
      return application(request, starter, respond);
    }

    FutureOr<void> catchError(Object error, StackTrace stackTrace) {
      ExceptionHandler? handler;

      if (error is HTTPException) {
        handler = statusHandlers[error.status];
      }

      if (handler == null) {
        handler = exceptionHandlers[error.runtimeType];
      }

      if (handler == null) {
        throw error;
      }

      if (responseStarted) {
        throw StateError(
            'Caught handled exception, but response already started');
      }

      FutureOr<Response> handle() {
        return handler!(request, error, stackTrace);
      }

      FutureOr<void> send(Response response) {
        return response(request, start, respond);
      }

      return Future<Response>.sync(handle).then<void>(send);
    }

    return Future<void>.sync(run).catchError(catchError);
  }

  static Response httpException(
    Request request,
    Object exception,
    StackTrace stackTrace,
  ) {
    final typedException = exception as HTTPException;

    if (typedException.status == 204 || typedException.status == 304) {
      return Response(status: typedException.status);
    }

    return TextResponse(typedException.message ?? '', status: exception.status);
  }
}
