library;

import 'dart:async' show Future, FutureOr;
import 'dart:developer' show Service;
import 'dart:io' show InternetAddress, Platform, SecurityContext;
import 'dart:isolate' show SendPort;
import 'dart:math' show max;

import 'package:astra/isolate.dart';
import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/devtools/register_extensions.dart';
import 'package:astra/src/logger.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/type.dart';
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
  /// {@macro astra_serve_handler}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    LoggerFactory? loggerFactory = defaultLoggerFactory,
  }) async {
    Future<Handler> handlerFactory() async {
      return await this;
    }

    return handlerFactory.serve(
      address,
      port,
      securityContextFactory: securityContextFactory,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
      type: type,
      isolates: isolates,
      loggerFactory: loggerFactory,
    );
  }
}

/// Extension on [HandlerFactory] to serve a HTTP server.
extension ServeHandlerFactoryExtension on FutureOr<HandlerFactory> {
  /// Starts a [Server] that listens on the specified [address] and [port] and
  /// sends requests to mounted [Handler] created by [HandlerFactory].
  ///
  /// {@template astra_serve_handler}
  /// The [address] can either be a [String] or an [InternetAddress]. If
  /// [address] is a [String], [ApplicationServer.bind] will perform a
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
  /// The optional argument [type] specifies the server implementation type
  /// to use. Defaults to [ServerType.shelf] (HTTP/1.x shelf server). See
  /// [ServerType] for available options.
  ///
  /// The optional argument [isolates] specifies the number of isolates to use
  /// for handling requests. If set to `0`, defaults to half the number of
  /// processor cores (minimum 1). Multiple isolates enable concurrent
  /// request processing and automatically set [shared] to `true`. Each isolate
  /// runs independently with its own copy of the application and context.
  ///
  /// The optional argument [loggerFactory] specifies a logger factory that
  /// creates a [Logger] for this [Server] instance.
  ///
  /// Factory functions ([HandlerFactory], [SecurityContextFactory],
  /// [LoggerFactory]) should avoid capturing large objects in their closures.
  /// {@endtemplate}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    LoggerFactory? loggerFactory = defaultLoggerFactory,
  }) async {
    if (isolates < 0) {
      throw RangeError.range(isolates, 0, null, 'isolates');
    } else if (isolates == 0) {
      isolates = max(1, Platform.numberOfProcessors ~/ 2 - 1);
    }

    shared = shared || isolates > 1;

    Future<Server> create(SendPort? sendPort) async {
      var handlerFactory = await this;
      var handler = await handlerFactory();

      SecurityContext? securityContext;

      if (securityContextFactory != null) {
        securityContext = await securityContextFactory();
      }

      Logger? logger;

      if (loggerFactory != null) {
        logger = await loggerFactory();
      }

      if (sendPort == null) {
        return await Server.bind(
          handler,
          address,
          port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
          type: type,
          logger: logger,
        );
      }

      return await IsolateServer.bind(
        sendPort,
        handler,
        address,
        port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        type: type,
        logger: logger,
      );
    }

    if (securityContextFactory != null) {
      // Check if the function is error-safe in the main isolate before spawning.
      await securityContextFactory();
    }

    Logger? logger;

    if (loggerFactory != null) {
      // Same check. We need a logger anyway.
      logger = await loggerFactory();
    }

    var url = getUrl(address, port, securityContextFactory != null);

    Server server;

    if (isolates == 1) {
      server = await create(null);
    } else {
      server = await MultiIsolateServer.spawn(
        isolates,
        create,
        url: url,
        logger: logger,
      );
    }

    registerExtensions(server);
    return server;
  }
}

/// Extension on [Application] to serve a HTTP server.
extension ServeApplicationExtension on FutureOr<Application> {
  /// Starts a [Server] that listens on the specified [address] and
  /// [port] and sends requests to mounted [Application].
  ///
  /// {@macro astra_serve_application}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    LoggerFactory? loggerFactory = defaultLoggerFactory,
  }) async {
    var applicationOrFuture = this;

    Future<Application> applicationFactory() async {
      return await applicationOrFuture;
    }

    return applicationFactory.serve(
      address,
      port,
      securityContextFactory: securityContextFactory,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
      type: type,
      isolates: isolates,
      loggerFactory: loggerFactory,
    );
  }
}

/// Extension on [ApplicationFactory] to serve a HTTP server.
extension ServeApplicationFactoryExtension on FutureOr<ApplicationFactory> {
  /// Starts a [Server] that listens on the specified [address] and
  /// [port] and sends requests to mounted [Application] created by
  /// [ApplicationFactory].
  ///
  /// {@template astra_serve_application}
  /// The [address] can either be a [String] or an [InternetAddress]. If
  /// [address] is a [String], [ApplicationServer.bind] will perform a
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
  /// The optional argument [shared] specifies whether additional
  /// [ApplicationServer] objects can bind to the same combination of [address],
  /// [port] and [v6Only]. If [shared] is `true` and more [Server]s from this
  /// isolate or other isolates are bound to the port, then the incoming
  /// connections will be distributed among all the bound [Server]s. Connections
  /// can be distributed over multiple isolates this way.
  ///
  /// The optional argument [type] specifies the server implementation type
  /// to use. Defaults to [ServerType.shelf] (HTTP/1.x shelf server). See
  /// [ServerType] for available options.
  ///
  /// The optional argument [isolates] specifies the number of isolates to use
  /// for handling requests. If set to `0`, defaults to half the number of
  /// processor cores (minimum 1). Multiple isolates enable concurrent
  /// request processing and automatically set [shared] to `true`. Each isolate
  /// runs independently with its own copy of the application and context.
  ///
  /// The optional argument [loggerFactory] specifies a logger factory that
  /// creates a [Logger] for this [Server] instance.
  ///
  /// Factory functions ([ApplicationFactory], [SecurityContextFactory],
  /// [LoggerFactory]) should avoid capturing large objects in their closures.
  /// {@endtemplate}
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContextFactory? securityContextFactory,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    LoggerFactory? loggerFactory = defaultLoggerFactory,
  }) async {
    if (isolates < 0) {
      throw RangeError.range(isolates, 0, null, 'isolates');
    } else if (isolates == 0) {
      isolates = max(1, Platform.numberOfProcessors ~/ 2 - 1);
    }

    shared = shared || isolates > 1;

    Future<ApplicationServer> create(SendPort? controlPort) async {
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

      if (controlPort == null) {
        return await ApplicationServer.bind(
          application,
          address,
          port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
          logger: logger,
        );
      }

      return await ApplicationIsolateServer.bind(
        controlPort,
        application,
        address,
        port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        logger: logger,
      );
    }

    if (securityContextFactory != null) {
      // Check if the function is error-safe in the main isolate before spawning.
      await securityContextFactory();
    }

    Logger? logger;

    if (loggerFactory != null) {
      // Same check. We need a logger anyway.
      logger = await loggerFactory();
    }

    var url = getUrl(address, port, securityContextFactory != null);

    Server server;

    if (isolates == 1) {
      server = await create(null);
    } else {
      server = await MultiIsolateServer.spawn(
        isolates,
        create,
        url: url,
        logger: logger,
      );
    }

    var info = await Service.getInfo();

    if (info.serverUri != null) {
      registerExtensions(server);
    }

    return server;
  }
}
