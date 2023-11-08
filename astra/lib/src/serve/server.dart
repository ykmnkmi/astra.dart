import 'dart:async' show Future;
import 'dart:io' show InternetAddress, SecurityContext;

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
  /// {@template server}
  /// The [address] can either be a [String] or an
  /// [InternetAddress]. If [address] is a [String], [Server.bind] will
  /// perform a [InternetAddress.lookup] and use the first value in the
  /// list. To listen on the loopback adapter, which will allow only
  /// incoming connections from the local host, use the value
  /// [InternetAddress.loopbackIPv4] or
  /// [InternetAddress.loopbackIPv6]. To allow for incoming
  /// connection from the network use either one of the values
  /// [InternetAddress.anyIPv4] or [InternetAddress.anyIPv6] to
  /// bind to all interfaces or the IP address of a specific interface.
  ///
  /// If an IP version 6 (IPv6) address is used, both IP version 6
  /// (IPv6) and version 4 (IPv4) connections will be accepted. To
  /// restrict this to version 6 (IPv6) only, use [v6Only] to set
  /// version 6 only.
  ///
  /// If [port] has the value 0 an ephemeral port will be chosen by
  /// the system. The actual port used can be retrieved using the
  /// [port] getter.
  ///
  /// The optional argument [backlog] can be used to specify the listen
  /// backlog for the underlying OS listen setup. If [backlog] has the
  /// value of 0 (the default) a reasonable value will be chosen by
  /// the system.
  ///
  /// If [requestClientCertificate] is true, the server will
  /// request clients to authenticate with a client certificate.
  /// The server will advertise the names of trusted issuers of client
  /// certificates, getting them from a [SecurityContext], where they have been
  /// set using [SecurityContext.setClientAuthorities].
  ///
  /// The optional argument [shared] specifies whether additional [Server]
  /// objects can bind to the same combination of [address], [port] and [v6Only].
  /// If [shared] is `true` and more [Server]s from this isolate or other
  /// isolates are bound to the port, then the incoming connections will be
  /// distributed among all the bound [Server]s. Connections can be
  /// distributed over multiple isolates this way.
  /// {@endtemplate}
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
    logger?.fine('Server.bind: Binding server...');

    var bind = switch (type) {
      ServerType.shelf => ShelfServer.bind,
    };

    var server = await bind(address, port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        logger: logger);

    logger?.fine('Server.bind: Server is bound successfully.');
    return server;
  }
}
