import 'dart:async' show Future, FutureOr;
import 'dart:io' show InternetAddress, Platform, SecurityContext;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/devtools/register_reloader.dart';
import 'package:astra/src/isolate/isolate_server.dart';
import 'package:astra/src/isolate/multi_isolate_server.dart';
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

extension ServeHandlerFactoryExtension on FutureOr<HandlerFactory> {
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
    Future<Application> applicationFactory() async {
      var handlerFactory = await this;
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

extension ServeApplicationFactoryExtension on FutureOr<ApplicationFactory> {
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
    var applicationFactoryFuture = this;

    InternetAddress internetAddress;

    if (address is InternetAddress) {
      internetAddress = address;
    } else if (address is String) {
      var addresses = await InternetAddress.lookup(address);
      // TODO(serve): can it be empty?
      internetAddress = addresses.first;
    } else {
      // TODO(serve): add error message
      throw ArgumentError.value(address, 'address');
    }

    if (isolates < 0) {
      // TODO(serve): add error message
      throw ArgumentError.value(isolates, 'isolates');
    } else if (isolates == 0) {
      isolates = Platform.numberOfProcessors;
    }

    shared = shared || isolates > 1;

    if (isolates == 1) {
      var server = await Server.bind(internetAddress, port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
          type: type);

      var applicationFactory = await applicationFactoryFuture;
      var application = await applicationFactory();

      if (hotReload || debug) {
        await registerReloader(application, server: server);
      }

      await server.mount(application);
      return server;
    }

    Future<Server> create(SendPort controlPort) async {
      var server = await Server.bind(internetAddress, port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
          type: type);

      var applicationFactory = await applicationFactoryFuture;
      var application = await applicationFactory();
      server = IsolateServer(server, controlPort);
      await server.mount(application);
      return server;
    }

    return await MultiIsolateServer.spawn(
        isolates, create, internetAddress, port,
        isSecure: securityContext != null);
  }
}
