import 'dart:io';

import 'package:astra/core.dart';
import 'package:shelf/shelf_io.dart';

class IOServer extends Server {
  IOServer(
    this.handler,
    Object address,
    int port, {
    SecurityContext? context,
    int backlog = 0,
    bool shared = false,
    bool v6Only = false,
  }) : super(address, port, //
            context: context,
            backlog: backlog,
            shared: shared,
            v6Only: v6Only);

  final Handler handler;

  late HttpServer server;

  @override
  Future<void> start() async {
    var context = this.context;

    if (context == null) {
      server = await HttpServer.bind(address, port, //
          backlog: backlog,
          shared: shared,
          v6Only: v6Only);
    } else {
      server = await HttpServer.bindSecure(address, port, context, //
          backlog: backlog,
          shared: shared,
          v6Only: v6Only);
    }

    serveRequests(server, handler);
  }

  @override
  Future<void> close() {
    return server.close();
  }
}
