import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
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
  InternetAddress get address;

  int get port;

  /// Mounts [application] as the base handler for this server.
  ///
  /// All requests to [url] or and URLs beneath it will be sent to [handlerFunction]
  /// until [close] is called.
  ///
  /// Throws a [StateError] if there's already a handler mounted.
  Future<void> mount(Application application, [Logger? logger]);

  /// Closes the server and returns a Future that completes when all resources
  /// are released.
  ///
  /// Once this is called, no more requests will be passed to this server's
  /// handler. Otherwise, the cleanup behavior is implementation-dependent.
  Future<void> close({bool force = false});
}
