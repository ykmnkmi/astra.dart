import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:shelf/shelf_io.dart';

// Modified version of serve from shelf package.
Future<Server> serve(Object application, Object address, int port,
    {SecurityContext? context, int backlog = 0, bool shared = false, bool v6Only = false}) async {
  var ioServer = await (context == null
      ? HttpServer.bind(address, port, backlog: backlog, shared: shared, v6Only: v6Only)
      : HttpServer.bindSecure(address, port, context,
          backlog: backlog, shared: shared, v6Only: v6Only));
  var handler = await getHandler(application);
  var server = IOServer(ioServer);
  server.mount(handler);
  return server;
}
