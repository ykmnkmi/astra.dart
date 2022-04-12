import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

import 'h11.dart';

Future<Server> serve(Handler application, Object address, int port, //
    {SecurityContext? securityContext,
    int backlog = 0,
    bool shared = false,
    bool requestClientCertificate = false,
    bool v6Only = false}) async {
  var server = await H11IOServer.bind(address, port, //
      securityContext: securityContext,
      backlog: backlog,
      shared: shared,
      requestClientCertificate: requestClientCertificate,
      v6Only: v6Only);
  server.mount(application);
  return server;
}
