// ignore: avoid_print

import 'dart:io' show stderr, stdout;

import 'package:astra/src/core/error.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/middleware.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
import 'package:astra/src/middlewares/utils.dart';
import 'package:stack_trace/stack_trace.dart' show Chain;

void _defaultLogger(String msg, bool isError) {
  if (isError) {
    stderr.writeln('[ERROR] $msg');
  } else {
    stdout.writeln(msg);
  }
}

String _formatQuery(String query) {
  return query == '' ? '' : '?$query';
}

String _message(
  DateTime requestTime,
  int statusCode,
  Uri requestedUri,
  String method,
  Duration elapsedTime,
) {
  return ''
      '${requestTime.toIso8601String()} '
      '${elapsedTime.toString().padLeft(15)} '
      '${method.padRight(7)} [$statusCode] ' // 7 - longest standard HTTP method
      '${requestedUri.path}${_formatQuery(requestedUri.query)}';
}

String _errorMessage(
  DateTime requestTime,
  Uri requestedUri,
  String method,
  Duration elapsedTime,
  Object error,
  StackTrace? stackTrace,
) {
  var chain = Chain.current();

  if (stackTrace != null) {
    chain = Chain.forTrace(stackTrace).foldFrames(isCoreFrame, terse: true);
  }

  return '$requestTime\t$elapsedTime\t$method\t${requestedUri.path}'
      '${_formatQuery(requestedUri.query)}\n$error\n$chain';
}

/// Middleware which prints the time of the request, the elapsed time for the
/// inner handlers, the response's status code and the request URI.
///
/// If [logger] is passed, it's called for each request. The `message` parameter
/// is a formatted string that includes the request time, duration, request
/// method, and requested path. When an exception is thrown, it also includes
/// the exception's string and stack trace; otherwise, it includes the status
/// code. The `isError` parameter indicates whether the message is caused by an
/// error.
///
/// If [logger] is not passed, the message is just passed to [print].
Middleware logRequests({void Function(String message, bool isError)? logger}) {
  var defaultLogger = logger ?? _defaultLogger;

  Handler middleware(Handler innerHandler) {
    Future<Response> handler(Request request) async {
      var startTime = DateTime.now();
      var watch = Stopwatch()..start();

      try {
        var response = await innerHandler(request);

        var msg = _message(
          startTime,
          response.statusCode,
          request.requestedUri,
          request.method,
          watch.elapsed,
        );

        defaultLogger(msg, false);
        return response;
      } on HijackException {
        rethrow;
      } catch (error, stackTrace) {
        var msg = _errorMessage(
          startTime,
          request.requestedUri,
          request.method,
          watch.elapsed,
          error,
          stackTrace,
        );

        defaultLogger(msg, true);
        rethrow;
      }
    }

    return handler;
  }

  return middleware;
}
