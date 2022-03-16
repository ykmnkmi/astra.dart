import 'dart:async';

import 'package:astra/src/core/manager.dart';
import 'package:shelf/shelf.dart';

abstract class Application {
  Application() {
    ApplicationManager.register(this);
  }

  FutureOr<Response> call(Request request);

  void reassemble() {}
}
