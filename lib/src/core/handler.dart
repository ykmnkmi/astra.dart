import 'package:astra/src/core/application.dart';
import 'package:shelf/shelf.dart';

export 'package:shelf/shelf.dart' show Handler;

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
