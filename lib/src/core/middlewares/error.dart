import 'dart:async';

import 'package:stack_trace/stack_trace.dart';

import '../http.dart';
import '../request.dart';
import '../response.dart';
import '../type.dart';

class ServerErrorMiddleware implements ApplicationController {
  ServerErrorMiddleware(this.application, {this.debug = false, this.handler});

  final Application application;

  final bool debug;

  final ExceptionHandler? handler;

  @override
  FutureOr<void> call(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
    if (scope['type'] != 'http') {
      return application(scope, receive, start, respond);
    }

    var responseStarted = false;

    void starter(int status, List<Header> headers) {
      responseStarted = true;
      start(status, headers);
    }

    return Future<void>.sync(() => application(scope, receive, starter, respond)).catchError((Object error, StackTrace stackTrace) {
      if (responseStarted) {
        throw error;
      }

      final request = Request(scope);

      if (!debug) {
        final accept = request.headers.get('accept');

        if (accept != null && accept.contains('text/html')) {
          final content = '';
          return HTMLResponse(content, status: 500).call(scope, start, respond);
        }

        final trace = Trace.format(stackTrace);
        return TextResponse('$error\n\n$trace', status: 500).call(scope, start, respond);
      }

      if (handler == null) {
        return TextResponse('Internal Server Error', status: 500).call(scope, start, respond);
      }

      return Future<Response>.sync(() => handler!(request, error, stackTrace)).then<void>((response) => response(scope, start, respond));
    });
  }
}
