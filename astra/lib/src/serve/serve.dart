import 'dart:async' show Future, FutureOr;
import 'dart:io' show InternetAddress, Platform, SecurityContext;
import 'dart:isolate' show Isolate, SendPort;
import 'dart:math' show min;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/devtools/register_extensions.dart';
import 'package:astra/src/isolate/isolate_server.dart';
import 'package:astra/src/isolate/multi_isolate_server.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/servers/h11.dart';
import 'package:logging/logging.dart' show Logger;

/// A factory that creates a [SecurityContext].
typedef SecurityContextFactory = FutureOr<SecurityContext> Function();

/// A factory that creates a [Logger].
typedef LoggerFactory = FutureOr<Logger> Function();

/// Extension on [Handler] to serve a HTTP server.
extension ServeHandlerExtension on FutureOr<Handler> {
  /// Starts a [Server] that listens on the specified [address] and [port] and
  /// sends requests to mounted [Handler].
  ///
  /// {@macro astra_serve}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    int isolates = 1,
    LoggerFactory? loggerFactory,
  }) async {
    Future<Application> handlerFactory() async {
      var handler = await this;
      return handler.asApplication();
    }

    return handlerFactory.serve(address, port,
        securityContextFactory: securityContextFactory,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        isolates: isolates,
        loggerFactory: loggerFactory);
  }
}

/// Extension on [HandlerFactory] to serve a HTTP server.
extension ServeHandlerFactoryExtension on FutureOr<HandlerFactory> {
  /// Starts a [Server] that listens on the specified [address] and [port] and
  /// sends requests to mounted [Handler] created by [HandlerFactory].
  ///
  /// {@macro astra_serve}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    int isolates = 1,
    LoggerFactory? loggerFactory,
  }) async {
    Future<Application> handlerFactory() async {
      var handlerFactory = await this;
      var handler = await handlerFactory();
      return handler.asApplication();
    }

    return handlerFactory.serve(address, port,
        securityContextFactory: securityContextFactory,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        isolates: isolates,
        loggerFactory: loggerFactory);
  }
}

/// Extension on [Application] to serve a HTTP server.
extension ServeApplicationExtension on FutureOr<Application> {
  /// Starts a [Server] that listens on the specified [address] and [port] and
  /// sends requests to mounted [Application].
  ///
  /// {@macro astra_serve}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    int isolates = 1,
    LoggerFactory? loggerFactory,
  }) async {
    var applicationOrFuture = this;

    Future<Application> applicationFactory() async {
      return await applicationOrFuture;
    }

    return applicationFactory.serve(address, port,
        securityContextFactory: securityContextFactory,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        isolates: isolates,
        loggerFactory: loggerFactory);
  }
}

/// Extension on [ApplicationFactory] to serve a HTTP server.
extension ServeApplicationFactoryExtension on FutureOr<ApplicationFactory> {
  /// Starts a [Server] that listens on the specified [address] and [port] and
  /// sends requests to mounted [Application] created by [ApplicationFactory].
  ///
  /// {@template astra_serve}
  /// The [address] can either be a [String] or an [InternetAddress]. If
  /// [address] is a [String], [Server.handle] will perform a
  /// [InternetAddress.lookup] and use the first value in the list. To listen
  /// on the loopback adapter, which will allow only incoming connections from
  /// the local host, use the value [InternetAddress.loopbackIPv4] or
  /// [InternetAddress.loopbackIPv6]. To allow for incoming connection from the
  /// network use either one of the values [InternetAddress.anyIPv4] or
  /// [InternetAddress.anyIPv6] to bind to all interfaces or the IP address of
  /// a specific interface.
  ///
  /// If [port] has the value `0`, an ephemeral port will be chosen by the
  /// system.
  ///
  /// Incoming client connections are promoted to secure connections, using the
  /// certificate and key set in [SecurityContext] created by
  /// [securityContextFactory].
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
  /// The optional argument [loggerFactory] specifies a logger factory that
  /// creates a [Logger] for this [Server] instance.
  /// {@endtemplate}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    int isolates = 1,
    LoggerFactory? loggerFactory,
  }) async {
    if (isolates < 0) {
      // TODO(serve): Add error message.
      throw ArgumentError.value(isolates, 'isolates');
    } else if (isolates == 0) {
      isolates = min(1, Platform.numberOfProcessors - 1);
    }

    shared = shared || isolates > 1;

    Future<Server> create(SendPort? controlPort) async {
      var applicationFactory = await this;
      var application = await applicationFactory();

      SecurityContext? securityContext;

      if (securityContextFactory != null) {
        securityContext = await securityContextFactory();
      }

      Logger? logger;

      if (loggerFactory != null) {
        logger = await loggerFactory();
      }

      Server server;

      if (controlPort == null) {
        server = H11Server(address, port,
            securityContext: securityContext,
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            shared: shared,
            identifier: 'server/main',
            logger: logger);
      } else {
        server = IsolateServer(controlPort, address, port,
            securityContext: securityContext,
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            shared: shared,
            identifier: Isolate.current.debugName,
            logger: logger);
      }

      await server.mount(application);
      return server;
    }

    if (isolates == 1) {
      var server = await create(null);
      registerExtensions(server);
      return server;
    }

    // Check security context before spawn.
    SecurityContext? securityContext;

    if (securityContextFactory != null) {
      securityContext = await securityContextFactory();
    }

    // Check logger before spawn.
    Logger? logger;

    if (loggerFactory != null) {
      logger = await loggerFactory();
    }

    var server = MultiIsolateServer(address, port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        identifier: 'main',
        logger: logger);

    await server.start(isolates, create);
    registerExtensions(server);
    return server;
  }
}
