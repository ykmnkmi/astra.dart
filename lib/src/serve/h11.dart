import 'dart:io';

import 'package:astra/core.dart';
import 'package:shelf/shelf_io.dart';

/// A HTTP/1.1 [Server] backed by a `dart:io` [HttpServer].
class H11IOServer extends Server {
  H11IOServer(this.server);

  /// The underlying [HttpServer].
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
  void mount(Handler handler) {
    serveRequests(server, handler);
  }

  @override
  Future<void> close() {
    return server.close();
  }

  /// Calls [HttpServer.bind] and wraps the result in an [H11IOServer].
  static Future<H11IOServer> bind(Object address, int port, //
      {SecurityContext? context,
      int backlog = 0,
      bool shared = false,
      bool requestClientCertificate = false,
      bool v6Only = false}) async {
    HttpServer server;

    if (context == null) {
      server = await HttpServer.bind(address, port, //
          backlog: backlog,
          shared: shared,
          v6Only: v6Only);
    } else {
      server = await HttpServer.bindSecure(address, port, context, //
          backlog: backlog,
          shared: shared,
          requestClientCertificate: requestClientCertificate,
          v6Only: v6Only);
    }

    return H11IOServer(server);
  }

  /// Serve a [Stream] of [HttpRequest]s.
  ///
  /// [HttpServer] implements [Stream<HttpRequest>] so it can be passed directly
  /// to [serveRequests].
  static void serveRequests(Stream<HttpRequest> requests, Handler handler) {
    requests.listen((request) {
      handleRequest(request, handler);
    });
  }
}
