import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class IsolateServer implements Server {
  static const String readyMessage = 'ready';

  static const String closeMessage = 'close';

  static const String closedMessage = 'closed';

  IsolateServer(this.server, this.sendPort) : receivePort = RawReceivePort() {
    void handler(Object? message) {
      if (message == closeMessage) {
        close();
        return;
      }

      throw UnsupportedError('$message');
    }

    receivePort.handler = handler;
    sendPort.send(receivePort.sendPort);
  }

  @internal
  final Server server;

  @internal
  final SendPort sendPort;

  @internal
  final RawReceivePort receivePort;

  @override
  Uri get url {
    return server.url;
  }

  // TODO(error): catch
  @override
  void mount(Handler handler, [Logger? logger]) {
    server.mount(handler, logger);
    sendPort.send(readyMessage);
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    sendPort.send(closedMessage);
  }
}
