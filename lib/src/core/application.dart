import 'dart:async';

import 'package:astra/core.dart';

abstract class Application {
  Handler get entryPoint;

  Future<void> prepare() async {}

  void reload() {}

  Future<void> close() async {}
}
