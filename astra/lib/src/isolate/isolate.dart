import 'dart:async' show Future;
import 'dart:io' show InternetAddress;
import 'dart:isolate' show ReceivePort, SendPort;

import 'package:astra/core.dart';
import 'package:astra/serve.dart';
import 'package:astra/src/isolate/message.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.controlPort) : _receivePort = ReceivePort() {
    void onMessage(Object? message) {
      switch (message) {
        case IsolateMessage.close:
          close();
          break;

        case IsolateMessage.closeForce:
          close(force: true);
          break;

        default:
          // TODO(isolate): update assert message
          assert(false, '');
      }
    }

    _receivePort.listen(onMessage);
    controlPort.send(_receivePort.sendPort);
  }

  final Server server;

  final SendPort controlPort;

  final ReceivePort _receivePort;

  @override
  Application? get application {
    return server.application;
  }

  @override
  InternetAddress get address {
    return server.address;
  }

  @override
  int get port {
    return server.port;
  }

  @override
  Uri get url {
    return server.url;
  }

  @override
  Future<void> get done {
    return server.done;
  }

  @override
  Future<void> mount(Application application) async {
    await server.mount(application);
    controlPort.send(IsolateMessage.ready);
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    _receivePort.close();
  }
}
