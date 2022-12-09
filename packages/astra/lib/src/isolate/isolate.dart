import 'dart:io' show InternetAddress;
import 'dart:isolate' show RawReceivePort, SendPort;

import 'package:astra/core.dart';
import 'package:astra/src/isolate/message.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.controlPort)
      : receivePort = RawReceivePort() {
    receivePort.handler = onMessage;
    controlPort.send(receivePort.sendPort);
  }

  final Server server;

  final SendPort controlPort;

  final RawReceivePort receivePort;

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

  void onMessage(Object? message) {
    if (message == IsolateMessage.close) {
      close();
      return;
    }

    // TODO: add error message
    throw UnimplementedError();
  }

  @override
  Future<void> mount(Application application) async {
    await server.mount(application);
    controlPort.send(IsolateMessage.ready);
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    controlPort.send(IsolateMessage.closed);
  }
}
