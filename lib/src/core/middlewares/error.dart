import 'dart:async';

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

    return Future<void>.sync(() => application(scope, receive, starter, respond)).catchError((Object error) {
      if (responseStarted) {
        throw error;
      }

      final request = Request(scope);

      if (debug) {
        final accept = request.headers.get('accept');

        if (accept != null && accept.contains('text/html')) {
          final content = '';
          return HTMLResponse(content, status: 500).call(scope, start, respond);
        }

        final content = '';
        return TextResponse(content, status: 500).call(scope, start, respond);
      }

      if (handler == null) {
        return TextResponse('Internal Server Error', status: 500)(scope, start, respond);
      }

      return Future<Response>.sync(() => handler!(request, error)).then<void>((response) => response(scope, start, respond));
    });
  }
}
