import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

/// An [adapter][] with a concrete URL.
///
/// [adapter]: https://github.com/dart-lang/shelf/tree/master/pkgs/shelf#adapters
abstract class Server {
  /// Mounted application.
  Application? get application;

  /// The address that the server is listening on.
  ///
  /// This is the actual address used when the original address
  /// was specified as a hostname.
  InternetAddress get address;

  /// This is the actual port used when the original port
  /// was specified as a zero.
  int get port;

  /// The URL of the server.
  ///
  /// Requests to this URL or any URL beneath it are handled by the handler
  /// passed to [mount]. If [mount] hasn't yet been called, the requests wait
  /// until it is. If [close] has been called, the handler will not be invoked;
  /// otherwise, the behavior is implementation-dependent.
  Uri get url;

  /// Mounts [application] as the base handler for this server.
  ///
  /// All requests will be sent to [application] until [close] is called.
  ///
  /// Throws a [StateError] if there's already a handler mounted.
  Future<void> mount(Application application);

  /// Closes the server and returns a Future that completes
  /// when all resources are released.
  ///
  /// Once this is called, no more requests will be passed to this server's
  /// handler. Otherwise, the cleanup behavior is implementation-dependent.
  Future<void> close({bool force = false});
}