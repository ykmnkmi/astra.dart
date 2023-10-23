import 'dart:async' show Future, FutureOr;

import 'package:astra/src/core/application.dart';
import 'package:shelf/shelf.dart' show Handler, Middleware;

export 'package:shelf/shelf.dart' show Handler;

/// A factory function that creates a [Handler].
typedef HandlerFactory = FutureOr<Handler> Function();

/// An extension on the [Handler] class.
extension HandlerExtension on Handler {
  /// Shorthand for `middleware(handler)`.
  Handler use(Middleware middleware) {
    return middleware(this);
  }

  /// Converts this [Handler] to an [Application].
  ///
  /// The optional [onClose] callback is invoked when the application is closed.
  Application asApplication([Future<void> Function()? onClose]) {
    return _HandlerApplication(this, onClose);
  }
}

final class _HandlerApplication extends Application {
  _HandlerApplication(this.entryPoint, [this.onClose]);

  @override
  final Handler entryPoint;

  final Future<void> Function()? onClose;

  @override
  Future<void> close() async {
    if (onClose case var onClose?) {
      await onClose();
    }
  }
}
