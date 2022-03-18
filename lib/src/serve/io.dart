import 'dart:io';

import 'package:astra/core.dart';
import 'package:shelf/shelf_io.dart';

class IOServer extends Server {
  IOServer(this.server);

  final HttpServer server;

  @override
  Uri get url {
    var address = server.address;

    if (address.isLoopback) {
      return Uri(scheme: 'http', host: 'localhost', port: server.port);
    }

    if (address.type == InternetAddressType.IPv6) {
      return Uri(scheme: 'http', host: '[${address.address}]', port: server.port);
    }

    return Uri(scheme: 'http', host: address.address, port: server.port);
  }

  @override
  Future<void> close() {
    return server.close();
  }

  static Future<IOServer> bind(Handler handler, Object address, int port, //
      {SecurityContext? context,
      int backlog = 0,
      bool shared = false,
      bool v6Only = false}) async {
    var server = await (context == null
        ? HttpServer.bind(address, port, //
            backlog: backlog,
            shared: shared,
            v6Only: v6Only)
        : HttpServer.bindSecure(address, port, context, //
            backlog: backlog,
            shared: shared,
            v6Only: v6Only));
    serveRequests(server, handler);
    return IOServer(server);
  }
}
