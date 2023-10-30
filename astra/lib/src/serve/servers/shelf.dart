import 'dart:async' show Completer;
import 'dart:io' show HttpServer, InternetAddressType, SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:shelf/shelf_io.dart' show serveRequests;

final class ShelfServer implements Server {
  ShelfServer(this.httpServer, {this.isSecure = false, this.logger})
      : _doneCompleter = Completer<void>();

  final HttpServer httpServer;

  final bool isSecure;

  @override
  final Logger? logger;

  final Completer<void> _doneCompleter;

  Application? _application;

  @override
  Application? get application => _application;

  @override
  Uri get url {
    var HttpServer(:address, :port) = httpServer;

    String host;

    if (address.isLoopback) {
      host = 'localhost';
    } else if (address.type == InternetAddressType.IPv6) {
      host = '[${address.address}]';
    } else {
      host = address.address;
    }

    return Uri(scheme: isSecure ? 'https' : 'http', host: host, port: port);
  }

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> mount(Application application) async {
    logger?.fine('ShelfServer.mount: Mounting application.');

    if (_application != null) {
      throw StateError("Can't mount two applications for the same server");
    }

    application.server = this;
    await application.prepare();
    serveRequests(httpServer, application.entryPoint);
    _application = application;
    logger?.fine('ShelfServer.mount: Serving requests.');
  }

  @override
  Future<void> close({bool force = false}) async {
    logger?.fine('ShelfServer.close: Closing HTTP shelf server.');

    if (_doneCompleter.isCompleted) {
      return;
    }

    await httpServer.close(force: force);

    if (application case var application?) {
      logger?.fine('ShelfServer.close: Closing application.');
      await application.close();
    }

    _doneCompleter.complete();
    logger?.fine('ShelfServer.close: Closing complete.');
  }

  static Future<ShelfServer> bind(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    Logger? logger,
  }) async {
    logger?.fine('ShelfServer.bind: Binding HTTP server.');

    var isSecure = securityContext != null;

    HttpServer server;

    if (isSecure) {
      server = await HttpServer.bindSecure(address, port, securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared);
    } else {
      server = await HttpServer.bind(address, port,
          backlog: backlog, v6Only: v6Only, shared: shared);
    }

    logger?.fine('ShelfServer.bind: Bound HTTP server.');
    return ShelfServer(server, isSecure: isSecure, logger: logger);
  }
}
