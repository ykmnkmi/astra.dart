import 'dart:async' show Completer, Future;
import 'dart:io' show InternetAddress, InternetAddressType;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/manager.dart';
import 'package:astra/src/serve/server.dart';

final class MultiIsolateServer implements Server {
  MultiIsolateServer(
    List<IsolateManager> managers,
    this.address,
    this.port, {
    bool isSecure = false,
  })  : _managers = managers,
        _isSecure = isSecure,
        _doneCompleter = Completer<void>();

  final List<IsolateManager> _managers;

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

    try {
      Future<void> close(int index) async {
        await _managers[index].stop(force: force);
      }

      var futures = List<Future<void>>.generate(_managers.length, close);
      await Future.wait<void>(futures);
    } finally {
      _doneCompleter.complete();
    }
  }

  static Future<MultiIsolateServer> spawn(
    int isolates,
    Future<Server> Function(SendPort?) spawn,
    Object address,
    int port, {
    bool isSecure = false,
  }) async {
    Future<IsolateManager> start(int index) async {
      return await IsolateManager.spawn(spawn, 'server/${index + 1}');
    }

    InternetAddress internetAddress;

    if (address is InternetAddress) {
      internetAddress = address;
    } else if (address is String) {
      var addresses = await InternetAddress.lookup(address);
      // TODO(serve): add assert message
      assert(addresses.isNotEmpty);
      internetAddress = addresses.first;
    } else {
      // TODO(serve): add error message
      throw ArgumentError.value(address, 'address');
    }

    var futures = List<Future<IsolateManager>>.generate(isolates, start);
    var managers = await Future.wait<IsolateManager>(futures);
    return MultiIsolateServer(managers, internetAddress, port,
        isSecure: isSecure);
  }
}
