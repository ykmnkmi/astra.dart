library astra.serve;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/isolate.dart';
import 'package:astra/src/serve/h11.dart';
import 'package:logging/logging.dart';

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
      SendPort? sendPort}) async {
    final server = await H11Server.bind(address, port, //
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared);

    if (sendPort == null) {
      server.mount(this, logger);
      return server;
    }

    final isolate = IsolateServer(server, sendPort);
    isolate.mount(this, logger);
    return isolate;
  }
}

extension ServeApplicationExtension on Application {
  Future<Server> serve(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false,
      Logger? logger}) async {
    final server = await H11Server.bind(address, port, //
        securityContext: securityContext,
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared);
    await prepare();
    server.mount(entryPoint, logger);
    return OnCloseServer(server, close);
  }
}
