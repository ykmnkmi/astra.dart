import 'dart:async' show Completer;
import 'dart:io'
    show HttpServer, InternetAddress, InternetAddressType, SecurityContext;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/serve/server.dart';
import 'package:shelf/shelf_io.dart' show serveRequests;

/// A HTTP/1.1 [Server] based on `package:shelf/shelf_io.dart`.
class ShelfServer implements Server {
  ShelfServer(HttpServer httpServer, {bool isSecure = false})
      : _httpServer = httpServer,
        _isSecure = isSecure,
        _doneCompleter = Completer<void>();

  final HttpServer _httpServer;

  final bool _isSecure;

  final Completer<void> _doneCompleter;

  Application? _application;

  @override
  Application? get application {
    return _application;
  }

  @override
  InternetAddress get address {
    return _httpServer.address;
  }

  @override
  int get port {
    return _httpServer.port;
  }

  @override
  Uri get url {
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
  Future<void> get done {
    return _doneCompleter.future;
  }

  @override
  Future<void> mount(Application application) async {
    if (_application != null) {
      throw StateError("Can't mount two applications for the same server");
    }

    _application = application;
    await application.prepare();
    serveRequests(_httpServer, application.entryPoint);
  }

  @override
  Future<void> close({bool force = false}) async {
    if (_doneCompleter.isCompleted) {
      return;
    }

    await _httpServer.close(force: force);

    if (application case var application?) {
      await application.close();
    }

    _doneCompleter.complete();
  }

  /// Bounds the [ShelfServer] to the given [address] and [port].
  static Future<ShelfServer> bind(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
  }) async {
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

    return ShelfServer(server, isSecure: isSecure);
  }
}
