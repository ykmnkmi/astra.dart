import 'dart:async';

import 'package:astra/src/core/shelf.dart';
import 'package:logging/logging.dart';

/// An [adapter][] with a concrete URL.
///
/// [adapter]: https://github.com/dart-lang/shelf#adapters
///
/// The most basic definition of "adapter" includes any function that passes
/// incoming requests to a [Handler] and passes its responses to some external
/// client. However, in practice, most adapters are also *servers*—that is,
/// they're serving requests that are made to a certain well-known URL.
///
/// This interface represents those servers in a general way. It's useful for
/// writing code that needs to know its own URL without tightly coupling that
/// code to a single server implementation.
///
/// Implementations of this interface are responsible for ensuring that the
/// members work as documented.
abstract class Server {
  /// The URL of the server.
  ///
  /// Requests to this URL or any URL beneath it are handled by the handler
  /// passed to [mount]. If [mount] hasn't yet been called, the requests wait
  /// until it is. If [close] has been called, the handler will not be invoked;
  /// otherwise, the behavior is implementation-dependent.
  Uri get url;

  /// Mounts [handler] as the base handler for this server.
  ///
  /// All requests to [url] or and URLs beneath it will be sent to [handler]
  /// until [close] is called.
  ///
  /// Throws a [StateError] if there's already a handler mounted.
  void mount(Handler handler, [Logger? logger]);

  /// Closes the server and returns a Future that completes when all resources
  /// are released.
  ///
  /// Once this is called, no more requests will be passed to this server's
  /// handler. Otherwise, the cleanup behavior is implementation-dependent.
  Future<void> close({bool force = false});
}

class OnCloseServer implements Server {
  OnCloseServer(this.server, this.onClose);

  final Server server;

  final Future<void> Function() onClose;

  @override
  Uri get url {
    return server.url;
  }

  @override
  void mount(Handler handler, [Logger? logger]) {
    server.mount(handler, logger);
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    await onClose();
  }
}
