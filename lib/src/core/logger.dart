import 'dart:io';

import 'package:stack_trace/stack_trace.dart' show Trace;

import 'handler.dart';
import 'middleware.dart';
import 'request.dart';

typedef LoggerCallback = void Function(String message, bool isError);

typedef LoggerFormatter = String Function(
    int statusCode, Request request, DateTime startTime, Duration duration);

String formatter(int code, Request request, DateTime start, Duration elapsed) {
  return '$start $elapsed [${request.method}] $code ${request.url}';
}

Middleware logger(LoggerCallback logger, {LoggerFormatter format = formatter}) {
  return (Handler handler) {
    return (Request request) async {
      var startTime = DateTime.now();
      var stopwatch = Stopwatch();
      stopwatch.start();

      try {
        var response = await handler(request);
        var message = format(response.statusCode, request, startTime, stopwatch.elapsed);
        logger(message, false);
        return response;
      } catch (error, stackTrace) {
        var message = format(HttpStatus.internalServerError, request, startTime, stopwatch.elapsed);
        message = '$message\n$error\n${Trace.format(stackTrace, terse: true)}';
        logger(message, true);
        rethrow;
      }
    };
  };
}
