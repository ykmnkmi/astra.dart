import 'dart:async';

import 'package:astra/core.dart';

abstract class Application {
  const Application();

  Handler get entryPoint;

  Future<void> prepare() async {}

  FutureOr<void> onReload() {}

  Future<void> onClose() async {}
}
