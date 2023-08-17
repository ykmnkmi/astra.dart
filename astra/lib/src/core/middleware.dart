import 'package:shelf/shelf.dart' show Handler, Middleware, Pipeline;

export 'package:shelf/shelf.dart' show Middleware;

/// [Middleware] extension.
extension MiddlewareExtension on Middleware {
  /// Similar to [Pipeline.addHandler].
  Handler handle(Handler handler) {
    return this(handler);
  }

  /// Similar to [Pipeline.addMiddleware].
  Middleware next(Middleware nextMiddleware) {
    Handler middleware(Handler handler) {
      return this(nextMiddleware(handler));
    }

    return middleware;
  }
}
