import 'dart:async' show FutureOr;

import 'package:shelf/shelf.dart' show Handler, Middleware;

export 'package:shelf/shelf.dart' show Handler;

/// A factory function that creates a [Handler].
typedef HandlerFactory = FutureOr<Handler> Function();

/// An extension on the [Handler] class that provides additional functionality.
extension HandlerExtension on Handler {
  /// Chains the current [Handler] with the provided [Middleware] and returns
  /// a new [Handler] that applies the current handler followed by the given
  /// middleware.
  ///
  /// This method allows you to create a new handler that applies the specified
  /// [Middleware] after the current handler, forming a middleware chain.
  Handler use(Middleware middleware) {
    return middleware(this);
  }
}
