import 'dart:async' show Future;
import 'dart:io'
    show HttpServer, InternetAddress, InternetAddressType, SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/serve/servers/h11.dart';
import 'package:logging/logging.dart' show Logger;

/// A running HTTP server with a concrete URL.
abstract interface class Server {
  /// Creates an instance of [Server].
  Server();

  /// The URL that the server is listening on.
  Uri get url;

  /// The logger of the instance.
  Logger? get logger;

  /// Closes the server and returns a future that completes when all resources
  /// are released.
  Future<void> close({bool force = false});

  /// Binds a [handler] to an [address] and [port].
  ///
  /// {@template astra_bind}
  /// The [address] can either be a [String] or an [InternetAddress]. If
  /// [address] is a [String], [bind] will perform a [InternetAddress.lookup]
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
  /// The optional argument [logger] specifies a logger for this [Server]
  /// instance.
  /// {@endtemplate}
  static Future<Server> bind(
    Handler handler,
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    Logger? logger,
  }) async {
    logger?.fine('Binding HTTP server...');

    HttpServer httpServer;

    if (securityContext != null) {
      httpServer = await HttpServer.bindSecure(
        address,
        port,
        securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
      );
    } else {
      httpServer = await HttpServer.bind(
        address,
        port,
        backlog: backlog,
        v6Only: v6Only,
        shared: shared,
      );
    }

    logger?.fine('Bound HTTP server.');
    logger?.fine('Listening for requests...');
    serveRequests(httpServer, handler, logger);
    logger?.fine('Server started.');

    return IOServer(
      httpServer,
      isSecure: securityContext != null,
      logger: logger,
    );
  }
}

/// A running HTTP server with a concrete URL.
final class IOServer implements Server {
  /// Creates an instance of [IOServer].
  IOServer(this.httpServer, {this.isSecure = false, this.logger});

  /// The underlying [HttpServer] instance.
  final HttpServer httpServer;

  /// Whether the server is secure.
  final bool isSecure;

  @override
  final Logger? logger;

  @override
  late final Uri url = getUrl(httpServer.address, httpServer.port, isSecure);

  @override
  Future<void> close({bool force = false}) async {
    logger?.fine('Closing server...');
    await httpServer.close(force: force);
    logger?.fine('Server closed.');
  }
}

/// A running application HTTP server with a concrete URL.
abstract interface class ApplicationServer implements Server {
  /// Creates an instance of [ApplicationServer].
  ApplicationServer();

  /// The application that is running on the server.
  Application get application;

  Future<void> reload();

  /// Binds a [application] to an [address] and [port].
  ///
  /// {@macro astra_bind}
  static Future<ApplicationServer> bind(
    Application application,
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    String? identifier,
    Logger? logger,
  }) async {
    logger?.fine('Preparing application...');
    await application.prepare();

    var server = await Server.bind(
      application.entryPoint,
      address,
      port,
      securityContext: securityContext,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
      logger: logger,
    );

    return ApplicationIOServer(application, server);
  }
}

/// A running application HTTP server with a concrete URL.
final class ApplicationIOServer implements ApplicationServer {
  /// Creates an instance of [ApplicationIOServer].
  ApplicationIOServer(this.application, this.server) {
    application.server = server;
  }

  @override
  final Application application;

  /// The underlying [Server] instance.
  final Server server;

  @override
  Uri get url => server.url;

  @override
  Logger? get logger => server.logger;

  @override
  Future<void> reload() async {
    logger?.fine('Reloading application...');
    await application.reload();
    logger?.fine('Application reloaded.');
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);

    logger?.fine('Closing application...');
    await application.close();
    logger?.fine('Application closed.');
  }
}

/// Makes a [Uri] for [Server].
Uri getUrl(Object address, int port, bool isSecure) {
  String host;

  if (address is InternetAddress) {
    if (address.isLoopback) {
      host = 'localhost';
    } else if (address.type == InternetAddressType.IPv6) {
      host = '[${address.address}]';
    } else {
      host = address.address;
    }
  } else {
    host = address as String;
  }

  return Uri(scheme: isSecure ? 'https' : 'http', host: host, port: port);
}
