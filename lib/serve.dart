library astra.serve;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/isolate.dart';
import 'package:astra/src/serve/h11.dart';
import 'package:logging/logging.dart';

export 'package:astra/src/serve/h11.dart';
export 'package:astra/src/serve/utils.dart';

extension ServeHandlerExtension on Handler {
  // TODO: add options: concurency, debug, ...
  // TODO: h1*, h2, h3, ..., websocket
  Future<Server> serve(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false,
      Logger? logger,
      SendPort? messagePort}) async {
    return asApplication().serve(address, port, //
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
  // TODO: h1*, h2, h3, ..., websocket
  Future<Server> serve(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false,
      Logger? logger,
      SendPort? messagePort}) async {
    var server = await H11Server.bind(address, port, //
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared);

    if (messagePort == null) {
      await server.mount(this, logger);
      return OnCloseServer(server, close);
    }

    var isolate = IsolateServer(server, messagePort);
    await isolate.mount(this, logger);
    return isolate;
  }
}
