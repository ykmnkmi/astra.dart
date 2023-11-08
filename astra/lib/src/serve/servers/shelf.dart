import 'dart:async' show Completer;
import 'dart:io' show HttpServer, InternetAddressType, SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:meta/meta.dart' show internal;
import 'package:shelf/shelf_io.dart' show serveRequests;

/// A server implementation using the `shelf` framework.
final class ShelfServer implements Server {
  /// Creates a new [ShelfServer] instance.
  @internal
  ShelfServer(HttpServer httpServer, {bool isSecure = false, this.logger})
      : _httpServer = httpServer,
        _isSecure = isSecure,
        _doneCompleter = Completer<void>();

  final HttpServer _httpServer;

  final bool _isSecure;

  final Completer<void> _doneCompleter;

  @override
  Application? get application => _application;

  Application? _application;

  @override
  final Logger? logger;

  @override
  Uri get url {
    var HttpServer(:address, :port) = _httpServer;

    String host;

    if (address.isLoopback) {
      host = 'localhost';
    } else if (address.type == InternetAddressType.IPv6) {
      host = '[${address.address}]';
    } else {
      host = address.address;
    }

    return Uri(scheme: _isSecure ? 'https' : 'http', host: host, port: port);
  }

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> mount(Application application) async {
    logger?.fine('ShelfServer.mount: Mounting application...');

    if (_application != null) {
      throw StateError("Can't mount two applications for the same server");
    }

    application.server = this;
    await application.prepare();
    serveRequests(_httpServer, application.entryPoint);
    _application = application;
    logger?.fine('ShelfServer.mount: Mounting application is complete. '
        'Serving requests.');
  }

  @override
  Future<void> close({bool force = false}) async {
    logger?.fine('ShelfServer.close: Closing server...');

    if (_doneCompleter.isCompleted) {
      return;
    }

    await _httpServer.close(force: force);

    if (application case var application?) {
      logger?.fine('ShelfServer.close: Closing application...');
      await application.close();
      logger?.fine('ShelfServer.close: Closing application is complete.');
    }

    _doneCompleter.complete();
    logger?.fine('ShelfServer.close: Closing server is complete.');
  }

  /// Binds the `shelf` [Server] to the given [address] and [port].
  ///
  /// {@macro server}
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
    logger?.fine('ShelfServer.bind: Binding server...');

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

    logger?.fine('ShelfServer.bind: Binding server is complete.');
    return ShelfServer(server, isSecure: isSecure, logger: logger);
  }
}
