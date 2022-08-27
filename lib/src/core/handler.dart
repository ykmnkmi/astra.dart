import 'dart:async';

import 'package:astra/src/core/application.dart';
import 'package:shelf/shelf.dart';

export 'package:shelf/shelf.dart' show Handler;

/// [Middleware] extension.
extension HandlerExtension on Handler {
  /// Same as `middleware(handler)`.
  Handler use(Middleware middleware) {
    return middleware(this);
  }

  Application asApplication({Future<void> Function()? onReload}) {
    return HandlerApplication(this, onReload: onReload);
  }
}

class HandlerApplication extends Application {
  const HandlerApplication(this.handler, {this.onReload});

  final Handler handler;

  final Future<void> Function()? onReload;

  @override
  Handler get entryPoint {
    return handler;
  }

  @override
  Future<void> reload() async {
    var onReload = this.onReload;

    if (onReload != null) {
      await onReload();
    }
  }
}
