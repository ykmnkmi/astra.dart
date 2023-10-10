import 'dart:async' show Future, FutureOr;

import 'package:astra/src/core/application.dart';
import 'package:shelf/shelf.dart' show Handler, Middleware;

export 'package:shelf/shelf.dart' show Handler;

/// [Handler] factory.
typedef HandlerFactory = FutureOr<Handler> Function();

/// [Middleware] extension.
extension HandlerExtension on Handler {
  /// Same as `middleware(handler)`.
  Handler use(Middleware middleware) {
    return middleware(this);
  }

  Application asApplication([Future<void> Function()? onClose]) {
    return _HandlerApplication(this, onClose);
  }
}

class _HandlerApplication extends Application {
  const _HandlerApplication(this.handler, [this.onClose]);

  final Handler handler;

  final Future<void> Function()? onClose;

  @override
  Handler get entryPoint {
    return handler;
  }

  @override
  Future<void> close() async {
    if (onClose case var onClose?) {
      await onClose();
    }
  }
}
