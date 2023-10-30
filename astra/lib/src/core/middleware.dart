import 'package:shelf/shelf.dart' show Handler, Middleware;

export 'package:shelf/shelf.dart' show Middleware;

/// An extension on the [Middleware] class that provides additional functionality.
extension MiddlewareExtension on Middleware {
  /// Chains the current middleware with a [handler] function and returns
  /// a new middleware handler that applies the current middleware followed
  /// by the given [handler].
  ///
  /// This method allows you to create a new middleware handler that combines
  /// the behavior of the current middleware and the specified [handler].
  Handler handle(Handler handler) {
    return this(handler);
  }

  /// Chains the current `middleware` with a [nextMiddleware] function and returns
  /// a new middleware handler that applies the current middleware followed by
  /// the [nextMiddleware].
  ///
  /// This method allows you to create a new middleware handler that chains the
  /// behavior of the current middleware and the [nextMiddleware], forming a
  /// sequence of middleware to process requests in the specified order.
  Middleware next(Middleware nextMiddleware) {
    Handler middleware(Handler handler) {
      return this(nextMiddleware(handler));
    }

    return middleware;
  }
}
