import 'dart:async';

import '../http.dart';
import '../request.dart';
import '../response.dart';
import '../type.dart';

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

class ExceptionMiddleware implements ApplicationController {
  ExceptionMiddleware(this.application, {Map<Object, ExceptionHandler>? handlers, this.debug = false})
      : statusHandlers = <int, ExceptionHandler>{},
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

  @override
  FutureOr<void> call(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
    var responseStarted = false;

    void starter(int status, List<Header> headers) {
      responseStarted = true;
      start(status, headers);
    }

    return Future<void>.sync(() => application(scope, receive, starter, respond)).catchError((Object error, StackTrace stackTrace) {
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
        throw StateError('Caught handled exception, but response already started');
      }

      final request = Request(scope, receive: receive);
      return Future<Response>.sync(() => handler!(request, error, stackTrace)).then<void>((response) => response(scope, start, respond));
    });
  }

  static Response httpException(Request request, Object exception, StackTrace stackTrace) {
    final typedException = exception as HTTPException;

    if (typedException.status == 204 || typedException.status == 304) {
      return Response(status: typedException.status);
    }

    return TextResponse(typedException.message ?? '', status: exception.status);
  }
}
