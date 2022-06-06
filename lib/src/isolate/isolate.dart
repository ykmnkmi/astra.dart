import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:meta/meta.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.sendPort) : receivePort = RawReceivePort() {
    receivePort.handler = listener;
    sendPort.send(receivePort.sendPort);
  }

  @protected
  final Server server;

  @protected
  final SendPort sendPort;

  @protected
  final RawReceivePort receivePort;

  @override
  Uri get url {
    return server.url;
  }

  @protected
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
