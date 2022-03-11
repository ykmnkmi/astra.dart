// Modified version of serve from shelf package.
library astra.serve;

import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:shelf/shelf_io.dart';

Future<Server> serve(Object object, Object address, int port,
    {SecurityContext? securityContext, int backlog = 0, bool shared = false}) async {
  var ioServer = await (securityContext == null
      ? HttpServer.bind(address, port, backlog: backlog, shared: shared)
      : HttpServer.bindSecure(address, port, securityContext, backlog: backlog, shared: shared));
  var handler = await getHandler(object);
  var server = IOServer(ioServer);
  server.mount(handler);
  return server;
}
