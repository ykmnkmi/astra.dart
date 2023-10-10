import 'dart:async' show Future, FutureOr;
import 'dart:io' show Platform, SecurityContext;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/devtools/reloader.dart';
import 'package:astra/src/isolate/isolate.dart';
import 'package:astra/src/isolate/multi.dart';
import 'package:astra/src/serve/h11.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/type.dart';

extension ServeHandlerExtension on FutureOr<Handler> {
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    bool hotReload = false,
    bool debug = false,
  }) async {
    if (isolates != 1) {
      // TODO(serve): add error message
      throw ArgumentError.value(isolates, 'isolates');
    }

    Future<Application> applicationFactory() async {
      var handler = await this;
      return handler.asApplication();
    }

    return applicationFactory.serve(address, port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        type: type,
        hotReload: hotReload,
        debug: debug);
  }
}

extension ServeHandlerFactoryExtension
    on FutureOr<FutureOr<Handler> Function()> {
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    bool hotReload = false,
    bool debug = false,
  }) async {
    var handlerFactory = await this;

    Future<Application> applicationFactory() async {
      var handler = await handlerFactory();
      return handler.asApplication();
    }

    return applicationFactory.serve(address, port,
        securityContext: securityContext,
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

extension ServeApplicationExtension on FutureOr<Application> {
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    bool hotReload = false,
    bool debug = false,
  }) async {
    if (isolates != 1) {
      // TODO(serve): add error message
      throw ArgumentError.value(isolates, 'isolates');
    }

    Future<Application> applicationFactory() async {
      return await this;
    }

    return applicationFactory.serve(address, port,
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        type: type,
        hotReload: hotReload,
        debug: debug);
  }
}

extension ServeApplicationFactoryExtension
    on FutureOr<FutureOr<Application> Function()> {
  Future<Server> serve(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    int isolates = 1,
    bool hotReload = false,
    bool debug = false,
  }) async {
    var applicationFactory = await this;

    if (isolates < 0) {
      // TODO(serve): add error message
      throw ArgumentError.value(isolates, 'isolates');
    } else if (isolates == 0) {
      isolates = Platform.numberOfProcessors;
    }

    shared = shared || isolates > 1;

    Future<Server> create(SendPort? controlPort) async {
      Server server = switch (type) {
        ServerType.shelf => await ShelfServer.bind(address, port,
            securityContext: securityContext,
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            shared: shared),
      };

      var application = await applicationFactory();

      if (hotReload || debug) {
        await registerReloader(application, server);
      }

      if (controlPort != null) {
        server = IsolateServer(server, controlPort);
      }

      await server.mount(application);
      return server;
    }

    if (isolates == 1) {
      return await create(null);
    }

    return await MultiIsolateServer.spawn(isolates, create, address, port,
        isSecure: securityContext != null);
  }
}
