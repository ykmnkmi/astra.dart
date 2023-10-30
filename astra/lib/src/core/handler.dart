import 'dart:async' show Future, FutureOr;

import 'package:astra/src/core/application.dart';
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

  /// Converts the current [Handler] into an [Application] with optional
  /// [onReload] and [onClose] callbacks.
  ///
  /// This method creates an [Application] instance using the current handler as
  /// the entry point, and allows you to specify optional callback functions to
  /// handle reload and closure events. The resulting [Application] can be used
  /// to define the behavior specific to your application and manage its lifecycle.
  Application asApplication({
    Future<void> Function()? onReload,
    Future<void> Function()? onClose,
  }) {
    return _HandlerApplication(this, onReload: onReload, onClose: onClose);
  }
}

/// A private class that extends [Application] and is used to convert a [Handler]
/// into an [Application] instance.
final class _HandlerApplication extends Application {
  _HandlerApplication(this.entryPoint, {this.onReload, this.onClose});

  @override
  final Handler entryPoint;

  final Future<void> Function()? onReload;

  final Future<void> Function()? onClose;

  @override
  Future<void> reload() async {
    if (onReload case var callback?) {
      await callback();
    }
  }

  @override
  Future<void> close() async {
    if (onClose case var callback?) {
      await callback();
    }
  }
}
