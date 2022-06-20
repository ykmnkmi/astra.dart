import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:logging/logging.dart';
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
    if (message == 'close') {
      return close();
    }

    throw UnsupportedError('$message');
  }

  // TODO(error): catch
  @override
  void mount(Handler handler, [Logger? logger]) {
    server.mount(handler, logger);
    sendPort.send('listening');
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    sendPort.send('closed');
  }
}
