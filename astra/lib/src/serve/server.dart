import 'dart:async' show Future;
import 'dart:io' show InternetAddress, InternetAddressType, SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:logging/logging.dart' show Logger;

/// A factory function that creates a [Server].
///
/// {@macro astra_server}
typedef ServerFactory = Future<Server> Function(
  Object address,
  int port, {
  SecurityContext? securityContext,
  int backlog,
  bool v6Only,
  bool requestClientCertificate,
  bool shared,
  String? identifier,
  Logger? logger,
});

/// Listens for HTTP requests and delivers them to its [Application] instance
/// or [Handler].
abstract base class Server {
  /// Base constructor for [Server].
  ///
  /// {@template astra_server}
  /// The [address] can either be a [String] or an [InternetAddress]. If
  /// [address] is a [String], [handle] will perform a [InternetAddress.lookup]
  /// and use the first value in the list. To listen on the loopback adapter,
  /// which will allow only incoming connections from the local host, use the
  /// value [InternetAddress.loopbackIPv4] or [InternetAddress.loopbackIPv6].
  /// To allow for incoming connection from the network use either one of the
  /// values [InternetAddress.anyIPv4] or [InternetAddress.anyIPv6] to bind to
  /// all interfaces or the IP address of a specific interface.
  ///
  /// If [port] has the value `0`, an ephemeral port will be chosen by the
  /// system. The actual port used can be retrieved using the [port] getter when
  /// the this server is started.
  ///
  /// Incoming client connections are promoted to secure connections, using the
  /// certificate and key set in [securityContext].
  ///
  /// The optional argument [backlog] can be used to specify the listen
  /// [backlog] for the underlying OS listen setup. If [backlog] has the value
  /// of `0` (the default) a reasonable value will be chosen by the system.
  ///
  /// If [requestClientCertificate] is `true`, the server will request clients
  /// to authenticate with a client certificate. The server will advertise the
  /// names of trusted issuers of client certificates, getting them from a
  /// [SecurityContext], where they have been set using
  /// [SecurityContext.setClientAuthorities].
  ///
  /// The optional argument [shared] specifies whether additional [Server]
  /// objects can bind to the same combination of [address], [port] and
  /// [v6Only]. If [shared] is `true` and more [Server]s from this isolate or
  /// other isolates are bound to the port, then the incoming connections will
  /// be distributed among all the bound [Server]s. Connections can be
  /// distributed over multiple isolates this way.
  ///
  /// The optional argument [identifier] specifies a unique identifier for this
  /// [Server] instance.
  ///
  /// The optional argument [logger] specifies a logger for this [Server]
  /// instance.
  /// {@endtemplate}
  Server(
    this.address,
    this.port, {
    this.securityContext,
    this.backlog = 0,
    this.v6Only = false,
    this.requestClientCertificate = false,
    this.shared = false,
    this.identifier,
    this.logger,
  });

  /// The instance of [Application] serving requests.
  Application? get application;

  /// The address that the server is listening on.
  final Object address;

  /// The port that the server is listening on.
  final int port;

  /// The URL that the server is listening on.
  Uri get url {
    String host;

    if (address case InternetAddress internetAddress) {
      if (internetAddress.isLoopback) {
        host = 'localhost';
      } else if (internetAddress.type == InternetAddressType.IPv6) {
        host = '[${internetAddress.address}]';
      } else {
        host = internetAddress.address;
      }
    } else {
      host = '$address';
    }

    return Uri(
        scheme: securityContext == null ? 'http' : 'http',
        host: host,
        port: port);
  }

  /// The security context used for secure HTTP connections.
  final SecurityContext? securityContext;

  final int backlog;

  /// Whether or not the [application] should only receive connections over
  /// IPv6.
  final bool v6Only;

  /// Whether or not the [application]'s request controllers should use
  /// client-side HTTPS certificates.
  final bool requestClientCertificate;

  final bool shared;

  /// The unique identifier of this instance.
  final String? identifier;

  /// The logger of this instance.
  final Logger? logger;

  /// Whether or not this server is running.
  bool get isRunning;

  /// Mounts [Handler] to this HTTP server.
  Future<void> handle(Handler handler);

  /// Mounts [Application] to this HTTP server.
  Future<void> mount(Application application);

  /// Closes this HTTP server and mounted [application].
  Future<void> close({bool force = false});
}
