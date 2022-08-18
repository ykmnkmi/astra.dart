library astra.core.extensions;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/shelf.dart';

/// [Middleware] extension.
extension MiddlewareExtension on Middleware {
  /// Similar to [Pipeline.addHandler].
  Handler handle(Handler handler) {
    return this(handler);
  }

  /// Similar to [Pipeline.addMiddleware].
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

  Application asApplication() {
    return HandlerApplication(this);
  }
}

class HandlerApplication extends Application {
  const HandlerApplication(this.handler);

  final Handler handler;

  @override
  Handler get entryPoint {
    return handler;
  }
}
