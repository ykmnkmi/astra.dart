import 'dart:io';

import 'package:astra/core.dart';
import 'package:shelf/shelf_io.dart';

class IOServer extends Server {
  IOServer(InternetAddress address, int port,
      {SecurityContext? context, int backlog = 0, bool shared = false, bool v6Only = false})
      : super(address, port, context: context, backlog: backlog, shared: shared, v6Only: v6Only);

  late HttpServer server;

  bool mounted = false;

  @override
  Future<void> start() async {
    var context = this.context;
    server = await (context == null
        ? HttpServer.bind(address, port, backlog: backlog, shared: shared, v6Only: v6Only)
        : HttpServer.bindSecure(address, port, context,
            backlog: backlog, shared: shared, v6Only: v6Only));
  }

  @override
  Future<void> close() async {
    await server.close();
  }

  @override
  void mount(Handler handler) {
    if (mounted) {
      // TODO: remount or throw error?
      return;
    }

    mounted = true;
    serveRequests(server, handler);
  }
}
