import 'dart:async';

import 'package:astra/core.dart';

/// An object that defines the behavior specific to your application.
abstract class Application {
  const Application();

  /// You implement this accessor to define how HTTP requests are handled by your application.
  Handler get entryPoint;

  /// You override this method to perform initialization tasks.
  Future<void> prepare() async {}

  /// You override this method to rerun any initialization tasks or update any resources.
  FutureOr<void> reload() {}

  /// You override this method to release any resources created in prepare.
  Future<void> close() async {}
}
