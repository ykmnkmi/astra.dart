import 'dart:async';

import 'package:astra/src/core/manager.dart';
import 'package:shelf/shelf.dart';

abstract class Application {
  Application() {
    ApplicationManager.register(this);
  }

  FutureOr<Response> call(Request request);

  void reassemble() {}

  static Application wrap(Handler handler, [void Function()? onReassemble]) {
    return ApplicationHandler(handler, onReassemble);
  }
}

class ApplicationHandler extends Application {
  ApplicationHandler(this.handler, [this.onReassemble]);

  final Handler handler;

  final void Function()? onReassemble;

  @override
  FutureOr<Response> call(Request request) {
    return handler(request);
  }

  @override
  void reassemble() {
    onReassemble?.call();
  }
}
