import 'dart:async' show Completer, Future;
import 'dart:io' show InternetAddress, InternetAddressType;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/isolate_supervisor.dart';
import 'package:astra/src/serve/server.dart';

// TODO(isolate): add hot reload support.
final class MultiIsolateServer extends SupervisorManager implements Server {
  MultiIsolateServer(
    this.address,
    this.port, {
    bool isSecure = false,
  })  : _isSecure = isSecure,
        _doneCompleter = Completer<void>();

  @override
  final InternetAddress address;

  @override
  final int port;

  final bool _isSecure;

  final Completer<void> _doneCompleter;

  @override
  Application? get application {
    // TODO(serve): add error message
    throw UnsupportedError('');
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
  Future<void> mount(Application application) {
    // TODO(serve): add error message
    throw UnsupportedError('');
  }

  @override
  Future<void> close({bool force = false}) async {
    if (_doneCompleter.isCompleted) {
      return;
    }

    stop(force: force);
    _doneCompleter.complete();
  }

  static Future<MultiIsolateServer> spawn(
    int isolates,
    Future<Server> Function(SendPort) spawn,
    InternetAddress address,
    int port, {
    bool isSecure = false,
  }) async {
    var server = MultiIsolateServer(address, port, isSecure: isSecure);
    await server.start(isolates, spawn);
    return server;
  }
}
