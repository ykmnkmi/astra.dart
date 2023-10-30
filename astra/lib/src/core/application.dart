import 'dart:async' show Future, FutureOr, StreamSubscription;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/handler.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:meta/meta.dart' show internal, nonVirtual;

/// A factory function that creates an [Application].
typedef ApplicationFactory = FutureOr<Application> Function();

/// An object that defines the behavior specific to your application.
///
/// This is the core class for defining your application's behavior. It includes
/// methods to handle HTTP requests and manage the application's lifecycle.
abstract base class Application {
  /// Creates an [Application].
  Application();

  /// Retrieves the handler responsible for handling HTTP requests in this
  /// application.
  Handler get entryPoint;

  /// Allows sending and receiving messages between different [Application]s.
  ///
  /// This message hub can be used to send data to applications running on other
  /// isolates.
  MessageHub? get messageHub => _messageHub;

  MessageHub? _messageHub;

  @internal
  @nonVirtual
  set messageHub(MessageHub? messageHub) {
    _messageHub = messageHub;
  }

  /// Retrieves the logger used for this application.
  Logger get logger => Logger('astra');

  /// Retrieves the [Server] responsible for sending HTTP requests to this
  /// application.
  @nonVirtual
  Server get server => _server!;

  Server? _server;

  @internal
  @nonVirtual
  set server(Server server) {
    _server = server;
  }

  /// Initializes the application and its services.
  ///
  /// Override this method to perform any necessary initialization tasks before
  /// handling HTTP requests. You can create and configure services in this
  /// method to be used by the [entryPoint].
  Future<void> prepare() async {}

  /// Reinitializes the application during development.
  ///
  /// Override this method to rerun initialization tasks or update resources
  /// while developing your application. This method is called only during
  /// development.
  Future<void> reload() async {}

  /// Releases any resources created in the `prepare` method.
  ///
  /// Override this method to release resources created during the application's
  /// initialization. This is important for cleanup when the application is
  /// closing.
  Future<void> close() async {}
}

/// An object that sends and receives messages between [Application] instances.
abstract interface class MessageHub implements Stream<Object?>, Sink<Object?> {
  /// Sends a message to all other hubs.
  ///
  /// [event] will be delivered to all other isolates that have set up a
  /// callback for [listen]. It must be isolate-safe data, or an error will be
  /// delivered to the listening isolate.
  ///
  /// See [SendPort.send] for more details on sending messages.
  @override
  void add(Object? event);

  /// Adds a listener for messages from other hubs.
  ///
  /// Use this method to add listeners for messages from other hubs. When
  /// another hub sends a message using the [add] method, this hub will receive
  /// it through the [onData] callback.
  ///
  /// If invalid data is sent, the optional [onError] callback can handle it.
  /// Only the isolate that failed to send the data will receive [onError] events.
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
