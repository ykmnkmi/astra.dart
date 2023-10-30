import 'dart:async' show Future;
import 'dart:io' show SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/serve/servers/shelf.dart';
import 'package:astra/src/serve/type.dart';
import 'package:logging/logging.dart' show Logger;

/// An abstract class representing a server adapter with a specific URL.
///
/// This class provides methods for managing an [Application], binding to a
/// specified address and port, and handling incoming requests. It serves as the
/// base for different server implementations.
abstract interface class Server {
  /// The mounted application for this server.
  Application? get application;

  /// The logger associated with this server.
  Logger? get logger;

  /// The URL of the server.
  ///
  /// Requests to this URL or any URL beneath it are handled by the [Application]
  /// passed to [mount].
  Uri get url;

  /// A future that completes when the server is done receiving requests.
  Future<void> get done;

  /// Mounts [application] as the base [Handler] for this server.
  ///
  /// All requests will be sent to [application] until [close] is called. If
  /// [mount] hasn't yet been called, the requests wait until it is. If
  /// [close] has been called, the handler will not be invoked.
  ///
  /// Throws a [StateError] if there's already an [application] mounted.
  Future<void> mount(Application application);

  /// Closes the mounted [Application] and returns a future that
  /// completes when all resources are released.
  ///
  /// Once this is called, no more requests will be passed to this server's
  /// [application].
  Future<void> close({bool force = false});

  /// Binds the [Server] to the given [address] and [port].
  ///
  /// This method binds the server to a specific [address] and [port], configuring
  /// various options such as [securityContext], [backlog], [v6Only],
  /// [requestClientCertificate], [shared], [type], and [logger].
  ///
  /// For a complete description of the arguments, please refer to the
  /// documentation in the code.
  static Future<Server> bind(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    Logger? logger,
  }) async {
    // Log binding information if a logger is provided.
    logger?.fine('Binding the HTTP server.');

    // Choose the appropriate binding method based on the server type.
    var bind = switch (type) {
      ServerType.shelf => ShelfServer.bind,
    };

    // Call the binding method to obtain a server instance.
    var server = await bind(address, port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        logger: logger);

    // Log success after binding.
    logger?.fine('The HTTP server is bound successfully.');
    return server;
  }
}
