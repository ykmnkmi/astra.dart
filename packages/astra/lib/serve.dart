// TODO: add debug, ...
library astra.serve;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/isolate.dart';
import 'package:astra/src/serve/h11.dart';

export 'package:astra/src/serve/h11.dart';
export 'package:astra/src/serve/utils.dart';

enum ServerType {
  h11,
}

extension ServeHandlerExtension on Handler {
  Future<Server> serve(
    Object address,
    int port, {
    ServerType type = ServerType.h11,
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    SendPort? messagePort,
  }) async {
    return asApplication().serve(
      address,
      port,
      type: type,
      securityContext: securityContext,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
      messagePort: messagePort,
    );
  }
}

extension ServeApplicationExtension on Application {
  Future<Server> serve(
    Object address,
    int port, {
    ServerType type = ServerType.h11,
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    SendPort? messagePort,
  }) async {
    Server server;

    switch (type) {
      case ServerType.h11:
        server = await ShelfServer.bind(
          address,
          port,
          securityContext: securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared,
        );

        break;
    }

    if (messagePort == null) {
      await server.mount(this);
      return server;
    }

    server = IsolateServer(server, messagePort);
    await server.mount(this);
    return server;
  }
}
