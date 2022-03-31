import 'dart:async';

import 'package:astra/core.dart';
import 'package:meta/meta.dart';

abstract class Application {
  late Server server;

  Handler get entryPoint;

  Future<void> prepare() async {}

  void onReload() {}

  @mustCallSuper
  Future<void> close() async {}
}
