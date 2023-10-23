import 'dart:async' show Future, FutureOr, StreamSubscription;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/handler.dart';
import 'package:meta/meta.dart' show internal, nonVirtual;

/// A factory function that creates an [Application].
typedef ApplicationFactory = FutureOr<Application> Function();

/// {@template application}
/// An object that defines the behavior specific to your application.
/// {@endtemplate}
abstract class Application {
  /// {@macro application}
  Application();

  /// Implement this accessor to define how HTTP requests are handled by
  /// application.
  Handler get entryPoint;

  /// Use this object to send data to the applications running on other
  /// isolates.
  @nonVirtual
  MessageHub? get messageHub => _messageHub;

  MessageHub? _messageHub;

  @internal
  @nonVirtual
  set messageHub(MessageHub? messageHub) {
    _messageHub = messageHub;
  }

  /// Override this method to perform initialization tasks.
  ///
  /// This method is invoked prior to [entryPoint], so that the services it
  /// creates can be injected into [Handler]s.
  Future<void> prepare() async {}

  /// Override this method to rerun any initialization tasks or update any
  /// resources while developing.
  ///
  /// This method will only be called during development.
  Future<void> reload() async {}

  /// Override this method to release any resources created in prepare.
  Future<void> close() async {}
}

/// An object that sends and receives messages between [Application]s.
abstract interface class MessageHub implements Stream<Object?>, Sink<Object?> {
  /// Sends a message to all other hubs.
  ///
  /// [event] will be delivered to all other isolates that have set up a
  /// callback for [listen].
  ///
  /// [event] must be isolate-safe data. If [event] is not isolate-safe data,
  /// an error is delivered to [listen] on this isolate.
  ///
  /// See [SendPort.send] for more details.
  @override
  void add(Object? event);

  /// Adds a listener for messages from other hubs.
  ///
  /// Use this method to add listeners for messages from other hubs.
  /// When another hub [add]s a message, this hub will receive it on [onData].
  ///
  /// [onError], if provided, will be invoked when this isolate tries to [add]
  /// invalid data. Only the isolate that failed to send the data will receive
  /// [onError] events.
  @override
  StreamSubscription<Object?> listen(
    void Function(Object? event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  });

  @override
  Future<void> close();
}
