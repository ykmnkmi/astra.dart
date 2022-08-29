library astra.serve;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/isolate.dart';
import 'package:astra/src/serve/shelf.dart';
import 'package:astra/src/serve/h11.dart';
import 'package:logging/logging.dart';

export 'package:astra/src/serve/shelf.dart';
export 'package:astra/src/serve/utils.dart';

enum ServerType {
  h11,
  shelf,
}

extension ServeHandlerExtension on Handler {
  // TODO: add options: concurency, debug, ...
  // TODO: h1*, h2, ...
  Future<Server> serve(Object address, int port,
      {Future<void> Function()? onReload,
      ServerType type = ServerType.shelf,
      SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false,
      Logger? logger,
      SendPort? messagePort}) async {
    var application = asApplication(onReload: onReload);
    return application.serve(address, port, //
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared,
        logger: logger,
        messagePort: messagePort);
  }
}

extension ServeApplicationExtension on Application {
  // TODO: add options: concurency, debug, ...
  // TODO: h1*, h2, ...
  Future<Server> serve(Object address, int port,
      {ServerType type = ServerType.shelf,
      SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false,
      Logger? logger,
      SendPort? messagePort}) async {
    Server server;

    switch (type) {
      case ServerType.h11:
        server = await H11Server.bind(address, port, //
            securityContext: securityContext,
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            shared: shared);
        break;

      case ServerType.shelf:
        server = await ShelfServer.bind(address, port, //
            securityContext: securityContext,
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            shared: shared);
        break;
    }

    if (messagePort == null) {
      await server.mount(this, logger);
      return server;
    }

    var isolate = IsolateServer(server, messagePort);
    await isolate.mount(this, logger);
    return isolate;
  }
}
