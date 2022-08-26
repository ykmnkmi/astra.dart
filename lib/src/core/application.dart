import 'dart:async';

import 'package:astra/src/core/handler.dart';

/// An object that defines the behavior specific to your application.
class Application {
  const Application();

  /// Implement this accessor to define how HTTP requests are handled by
  /// your application.
  Handler get entryPoint {
    throw UnimplementedError();
  }

  /// Override this method to perform initialization tasks.
  Future<void> prepare() async {}

  /// Override this method to rerun any initialization tasks or update any
  /// resources while developing.
  FutureOr<void> reload() {}

  /// Override this method to release any resources created in prepare.
  Future<void> close() async {}
}
