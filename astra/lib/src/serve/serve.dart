import 'dart:async' show Future, FutureOr;
import 'dart:io'
    show InternetAddress, InternetAddressType, Platform, SecurityContext;
import 'dart:isolate' show SendPort;
import 'dart:math' show min;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/devtools/register_hot_reloader.dart';
import 'package:astra/src/isolate/isolate_server.dart';
import 'package:astra/src/isolate/multi_isolate_server.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/type.dart';
import 'package:logging/logging.dart' show Logger;

typedef SecurityContextFactory = FutureOr<SecurityContext> Function();

/// Extension on [Handler] to serve a single HTTP server.
extension ServeHandlerExtension on FutureOr<Handler> {
  /// Serves the specified [Handler] by creating and configuring an HTTP server.
  ///
  /// {@macro serve}
  ///
  /// Returns a [Server] instance representing the running HTTP server.
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
    bool hotReload = false,
    bool debug = false,
    Logger? logger,
  }) async {
    var handlerOrFuture = this;

    Future<Application> handlerFactory() async {
      var handler = await handlerOrFuture;
      return handler.asApplication();
    }

    return handlerFactory.serve(address, port,
        securityContextFactory: securityContextFactory,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        type: type,
        hotReload: hotReload,
        debug: debug,
        logger: logger);
  }
}

/// Extension on [HandlerFactory] to serve a single HTTP server.
extension ServeHandlerFactoryExtension on FutureOr<HandlerFactory> {
  /// Serves the [HandlerFactory] by creating and configuring an HTTP server.
  ///
  /// {@macro serve}
  ///
  /// Returns a [Server] instance representing the running HTTP server.
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
    bool hotReload = false,
    bool debug = false,
    Logger? logger,
  }) async {
    var handlerFactoryOrFuture = this;

    Future<Application> handlerFactory() async {
      var handlerFactory = await handlerFactoryOrFuture;
      var handler = await handlerFactory();
      return handler.asApplication();
    }

    return handlerFactory.serve(address, port,
        securityContextFactory: securityContextFactory,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        type: type,
        isolates: isolates,
        hotReload: hotReload,
        debug: debug);
  }
}

/// Extension on [Application] to serve a single HTTP server.
extension ServeApplicationExtension on FutureOr<Application> {
  /// Serves the specified [Application] by creating and configuring an HTTP
  /// server.
  ///
  /// {@macro serve}
  ///
  /// Returns a [Server] instance representing the running HTTP server.
  // TODO(serve): check http://dartbug.com/36983 and document it
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
    bool hotReload = false,
    bool debug = false,
    Logger? logger,
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
        type: type,
        hotReload: hotReload,
        debug: debug);
  }
}

/// Extension on [ApplicationFactory] to serve a single HTTP server.
extension ServeApplicationFactoryExtension on FutureOr<ApplicationFactory> {
  /// Serves the [ApplicationFactory] by creating and configuring an HTTP
  /// server.
  ///
  /// {@template serve}
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
  ///
  /// If [isolates] is set to 1, a single HTTP server is created. If [isolates]
  /// is set to 0, a reasonable value will be chosen by the system. If
  /// [hotReload] or [debug] is enabled, the hot-reloading callback is
  /// registered. Otherwise, the server runs with no hot-reloading support.
  /// {@endtemplate}
  ///
  /// Returns a [Server] instance representing the running HTTP server.
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
    bool hotReload = false,
    bool debug = false,
    Logger? logger,
  }) async {
    var applicationFactoryOrFuture = this;

    InternetAddress internetAddress;

    if (address is InternetAddress) {
      internetAddress = address;
    } else if (address is String) {
      var addresses = await InternetAddress.lookup(address);
      // TODO(serve): is this can be empty?
      internetAddress = addresses.first;
    } else {
      // TODO(serve): add error message
      throw ArgumentError.value(address, 'address');
    }

    if (isolates < 0) {
      // TODO(serve): add error message
      throw ArgumentError.value(isolates, 'isolates');
    } else if (isolates == 0) {
      isolates = min(1, Platform.numberOfProcessors - 1);
    }

    shared = shared || isolates > 1;

    if (isolates == 1) {
      SecurityContext? securityContext;

      if (securityContextFactory != null) {
        securityContext = await securityContextFactory();
      }

      var server = await Server.bind(internetAddress, port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
          type: type);

      var applicationFactory = await applicationFactoryOrFuture;
      var application = await applicationFactory();

      if (hotReload || debug) {
        await registerHotReloader(application.reload, server.done);
      }

      await server.mount(application);
      return server;
    }

    String host;

    if (internetAddress.isLoopback) {
      host = 'localhost';
    } else if (internetAddress.type == InternetAddressType.IPv6) {
      host = '[${internetAddress.address}]';
    } else {
      host = internetAddress.address;
    }

    var url = Uri(
        scheme: securityContextFactory == null ? 'http' : 'https',
        host: host,
        port: port);

    Future<IsolateServer> create(SendPort controlPort) async {
      SecurityContext? securityContext;

      if (securityContextFactory != null) {
        securityContext = await securityContextFactory();
      }

      var server = await Server.bind(internetAddress, port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
          type: type,
          logger: logger);

      var applicationFactory = await applicationFactoryOrFuture;
      var application = await applicationFactory();
      var isolateServer = IsolateServer(server, controlPort);
      await isolateServer.mount(application);
      return isolateServer;
    }

    var server = await MultiIsolateServer.spawn(url, isolates, create);

    if (hotReload || debug) {
      await registerHotReloader(server.reload, server.done);
    }

    return server;
  }
}
