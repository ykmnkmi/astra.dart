import 'dart:io';

import 'package:shelf/shelf.dart';

typedef LoggerCallback = void Function(String message, [Object? error, StackTrace? stackTrace]);

typedef LoggerFormatter = String Function(
    int statusCode, Request request, DateTime startTime, Duration duration);

String formatter(int code, Request request, DateTime start, Duration elapsed) {
  var uri = request.requestedUri;
  var path = uri.path;
  var query = uri.query;

  if (query.isNotEmpty) {
    query = '?$query';
  }

  Function.apply;
  return '${start.toIso8601String()} $elapsed ${request.method.padRight(7)} [$code] $path$query';
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
        logger(message);
        return response;
      } catch (error, stackTrace) {
        var message = format(HttpStatus.internalServerError, request, startTime, stopwatch.elapsed);
        logger(message, error, stackTrace);
        rethrow;
      }
    };
  };
}
