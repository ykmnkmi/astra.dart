import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/io.dart';
import 'package:astra/src/serve/utils.dart';

Future<Server> serve(Object application, Object address, int port, //
    {SecurityContext? context,
    int backlog = 0,
    bool shared = false,
    bool requestClientCertificate = false,
    bool v6Only = false}) async {
  var handler = await getHandler(application);
  var server = await IOServer.bind(address, port, //
      context: context,
      backlog: backlog,
      shared: shared,
      requestClientCertificate: requestClientCertificate,
      v6Only: v6Only);
  server.mount(handler);
  return server;
}
