import 'dart:async' show FutureOr;

import 'http.dart';
import 'request.dart';
import 'response.dart';

typedef Start = void Function({int status, String? reason, List<Header>? headers});

typedef Send = FutureOr<void> Function({List<int> bytes, bool flush, bool end});

typedef Application = FutureOr<void> Function(Request request, Start start, Send send);

typedef Handler = FutureOr<Response> Function(Request request);

extension HandlerPipeline on Handler {
  Handler use(Middleware middleware) {
    return middleware(this);
  }
}

typedef ExceptionHandler = FutureOr<Response> Function(Request request, Object error, StackTrace stackTrace);

typedef Middleware = Handler Function(Handler handler);

extension MiddlewarePipeline on Middleware {
  Middleware link(Middleware next) {
    return (Handler handler) {
      return this(handler);
    };
  }

  Handler handle(Handler handler) {
    return (Request request) {
      return handler(request);
    };
  }
}
