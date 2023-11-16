import 'dart:async' show Future, FutureOr, StreamSubscription;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/handler.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:meta/meta.dart' show internal, nonVirtual;

/// A factory function that creates an [Application].
typedef ApplicationFactory = FutureOr<Application> Function();

/// An object that defines the behavior specific to application.
///
/// Create a subclass of [Application] to initialize application's services and
/// define how HTTP requests are handled by application.
///
/// Implement [entryPoint] to define the handler that comprise application.
/// Override [prepare] to read configuration values and initialize services.
abstract base class Application {
  /// Creates an instance of [Application].
  Application();

  /// Implement this accsessor to define how HTTP requests are handled by application.
  ///
  /// Implement this accsessor to return the handler that will handle an HTTP
  /// request. This accsessor is invoked during startup and handler cannot be
  /// changed after it is invoked. This accsessor is always invoked after
  /// [prepare].
  ///
  /// In most applications, the handler is a router. Example with `shelf_router`:
  /// ```dart
  /// @override
  /// Handler get entryPoint {
  ///   return Router()
  ///    ..get('/hello', (Request request) => Response.ok('Hello World!'))
  ///    ..get('/user/<user>', (Request request, String user) => Response.ok('Hello $user!'));
  /// }
  /// ```
  Handler get entryPoint;

  /// Use this object to send data to applications running on other isolates.
  ///
  /// Use this object to synchronize state across the isolates of an
  /// application. Any data sent through this object will be received by every
  /// other channel in your application (except the one that sent it).
  @nonVirtual
  MessageHub? get messageHub => _messageHub;

  MessageHub? _messageHub;

  @internal
  @nonVirtual
  set messageHub(MessageHub? messageHub) {
    _messageHub = messageHub;
  }

  /// The logger that this object will write messages to.
  ///
  /// This logger's name appears as 'astra'.
  Logger get logger => Logger('astra');

  /// The [Server] that sends HTTP requests to this object.
  @nonVirtual
  Server? get server => _server;

  Server? _server;

  @internal
  @nonVirtual
  set server(Server? server) {
    _server = server;
  }

  /// Override this method to perform initialization tasks.
  ///
  /// This method allows this instance to perform any initialization (other than
  /// setting up the [entryPoint]). This method is often used to set up services
  /// that [Handler]s use to fulfill their duties. This method is invoked prior
  /// to [entryPoint], so that the services it creates can be injected into [Handler]s.
  ///
  /// By default, this method does nothing.
  Future<void> prepare() async {}

  Future<void> reload() async {}

  /// Override this method to release any resources created in [prepare].
  ///
  /// This method is invoked when the owning [Application] is stopped. It closes
  /// open ports that this application was using so that the application can be
  /// properly shut down.
  Future<void> close() async {}
}

/// An object that sends and receives messages between [Application]s.
///
/// Use this object to share information between isolates. Each [Application]
/// has a property of this type. A message sent through this object
/// is received by every other application through its hub.
///
/// To receive messages in a hub, add a listener via [listen]. To send messages,
/// use [add].
abstract interface class MessageHub implements Stream<Object?>, Sink<Object?> {
  /// Sends a message to all other hubs.
  ///
  /// [event] will be delivered to all other isolates that have set up a
  /// callback for [listen].
  ///
  /// [event] must be isolate-safe data - in general, this means it may not be
  /// or contain a closure.  If [event] is not isolate-safe data, an error is
  /// delivered to [listen] on this isolate. See [SendPort.send] for more details.
  @override
  void add(Object? event);

  /// Adds a listener for messages from other hubs.
  ///
  /// Use this method to add listeners for messages from other hubs. When
  /// another hub [add]s a message, this hub will receive it on [onData].
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
