import 'package:shelf/shelf.dart';

extension MiddlewareExtension on Middleware {
  Handler handle(Handler handler) {
    return this(handler);
  }

  Middleware next(Middleware middleware) {
    return (Handler handler) {
      return this(middleware(handler));
    };
  }
}

extension HandlerExtension on Handler {
  Handler use(Middleware middleware) {
    return middleware(this);
  }
}
