import 'dart:async';

import 'package:astra/src/core/manager.dart';
import 'package:shelf/shelf.dart';

abstract class Controller {
  Controller() {
    ControllerManager.register(this);
  }

  FutureOr<Response> call(Request request);

  void reassemble() {}

  static Controller wrap(Handler handler, [void Function()? onReassemble]) {
    return ControllerHandler(handler, onReassemble);
  }
}

class ControllerHandler extends Controller {
  ControllerHandler(this.handler, [this.onReassemble]);

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
