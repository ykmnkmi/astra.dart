import 'dart:async' show Future;
import 'dart:io' show InternetAddress, SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/serve/servers/shelf.dart';
import 'package:astra/src/serve/type.dart';

/// A server [adapter][] with a concrete URL.
///
/// [adapter]: https://github.com/dart-lang/shelf/tree/master/pkgs/shelf#adapters
abstract interface class Server {
  /// The mounted application.
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

  /// A future which is completed when the server is done receiving requests.
  Future<void> get done;

  /// Mounts [application] as the base [Handler] for this server.
  ///
  /// All requests will be sent to [application] until [close] is called.
  ///
  /// Throws a [StateError] if there's already a [application] mounted.
  Future<void> mount(Application application);

  /// Closes the mounted [Application] and returns a future that
  /// completes when all resources are released.
  ///
  /// Once this is called, no more requests will be passed to this server's
  /// [application]. Otherwise, the cleanup behavior is
  /// implementation-dependent.
  Future<void> close({bool force = false});

  /// Bounds the [Server] to the given [address] and [port].
  // TODO(serve): document parameters
  static Future<Server> bind(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
  }) async {
    return switch (type) {
      ServerType.shelf => await ShelfServer.bind(address, port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared),
    };
  }
}
