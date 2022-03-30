import 'dart:async';

import 'package:astra/src/core/controller.dart';

abstract class Application extends Controller {
  Future<void> prepare() async {}
}
