import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/h11.dart';

Future<Server> serve(Handler handler, Object address, int port, //
    {SecurityContext? context,
    int backlog = 0,
    bool shared = false,
    bool requestClientCertificate = false,
    bool v6Only = false}) async {
  var server = await H11IOServer.bind(address, port, //
      context: context,
      backlog: backlog,
      shared: shared,
      requestClientCertificate: requestClientCertificate,
      v6Only: v6Only);
  server.mount(handler);
  return server;
}
