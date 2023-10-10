import 'dart:async' show Future;
import 'dart:io' show InternetAddress;
import 'dart:isolate' show ReceivePort, SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/serve/server.dart';

class IsolateServer implements Server {
  IsolateServer(Server server, SendPort controlPort)
      : _server = server,
        _controlPort = controlPort,
        _receivePort = ReceivePort() {
    void onMessage(Object? message) {
      switch (message) {
        case bool force:
          close(force: force);
          break;
        default:
          // TODO(isolate): add error message
          throw UnsupportedError('');
      }
    }

    _receivePort.listen(onMessage);
  }

  final Server _server;

  final SendPort _controlPort;

  final ReceivePort _receivePort;

  @override
  Application? get application {
    return _server.application;
  }

  @override
  InternetAddress get address {
    return _server.address;
  }

  @override
  int get port {
    return _server.port;
  }

  @override
  Uri get url {
    return _server.url;
  }

  @override
  Future<void> get done {
    return _server.done;
  }

  @override
  Future<void> mount(Application application) async {
    await _server.mount(application);
    _controlPort.send(_receivePort.sendPort);
  }

  @override
  Future<void> close({bool force = false}) async {
    await _server.close(force: force);
    _receivePort.close();
  }
}
