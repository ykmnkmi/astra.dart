import 'dart:io' show HttpStatus;

import 'package:stack_trace/stack_trace.dart' show Trace;

import 'http.dart';
import 'request.dart';
import 'types.dart';

typedef LoggerCallback = void Function(String message, bool isError);

String format(int code, Request request, DateTime start, Duration elapsed) {
  return '$start $elapsed [${request.method}] $code ${request.uri}';
}

Application log(Application application, {required LoggerCallback logger}) {
  return (Request request) async {
    var startTime = DateTime.now();
    var stopwatch = Stopwatch();
    stopwatch.start();

    var start = request.start;
    var code = HttpStatus.ok;

    request.start = (int status, {List<Header>? headers, bool buffer = true}) {
      code = status;
      start(status, headers: headers, buffer: buffer);
    };

    try {
      await application(request);
      var message = format(code, request, startTime, stopwatch.elapsed);
      logger(message, false);
    } catch (error, stackTrace) {
      var message = format(code, request, startTime, stopwatch.elapsed);
      message = '$message\n$error\n${Trace.format(stackTrace, terse: true)}';
      logger(message, true);
      rethrow;
    }
  };
}
