import 'dart:async' show Future;

import 'package:astra/src/core/handler.dart';

/// {@template application}
/// An object that defines the behavior specific to your application.
/// {@endtemplate}
abstract class Application {
  /// {@macro application}
  const Application();

  /// Implement this accessor to define how HTTP requests are handled by
  /// your application.
  Handler get entryPoint;

  /// Override this method to perform initialization tasks.
  Future<void> prepare() async {}

  /// Override this method to rerun any initialization tasks or update any
  /// resources while developing.
  Future<void> reload() async {}

  /// Override this method to release any resources created in prepare.
  Future<void> close() async {}
}
