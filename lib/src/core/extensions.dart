import 'package:shelf/shelf.dart';

/// [Middleware] extension.
extension MiddlewareExtension on Middleware {
  /// Similar to [Pipeline.addMiddleware].
  Handler handle(Handler handler) {
    return this(handler);
  }

  /// Similar to [Pipeline.addHandler].
  Middleware next(Middleware middleware) {
    return (Handler handler) {
      return this(middleware(handler));
    };
  }
}

/// [Middleware] extension.
extension HandlerExtension on Handler {
  /// Same as `middleware(handler)`.
  Handler use(Middleware middleware) {
    return middleware(this);
  }
}
