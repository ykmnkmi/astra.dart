import 'dart:isolate';

import 'package:astra/core.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.sendPort) : receivePort = RawReceivePort() {
    receivePort.handler = listener;
    sendPort.send(receivePort.sendPort);
  }

  final Server server;

  final SendPort sendPort;

  final RawReceivePort receivePort;

  @override
  Uri get url {
    return server.url;
  }

  Future<void> listener(Object? message) {
    if (message == 'stop') {
      return close();
    }

    throw UnsupportedError('$message');
  }

  @override
  void mount(Handler handler) {
    sendPort.send('listening');
    server.mount(handler);
  }

  @override
  Future<void> close() async {
    await server.close();
    sendPort.send('stop');
  }
}
