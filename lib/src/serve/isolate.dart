import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';
import 'package:meta/meta.dart';

class IsolateServer implements Server {
  @visibleForTesting
  IsolateServer(this.server, this.sendPort) : receivePort = ReceivePort() {
    receivePort.listen(listener);
    sendPort.send(receivePort.sendPort);
  }

  final IOServer server;

  final SendPort sendPort;

  final ReceivePort receivePort;

  @override
  Uri get url {
    return server.url;
  }

  Future<void> listener(Object? message) {
    if (message == 'stop') {
      return close();
    }

    throw UnimplementedError();
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

  static Future<IsolateServer> start(SendPort sendPort, Object address, int port, //
      {SecurityContext? context,
      int backlog = 0,
      bool shared = false,
      bool v6Only = false}) async {
    var server = await IOServer.bind(address, port, //
        context: context,
        backlog: backlog,
        shared: shared,
        v6Only: v6Only);
    return IsolateServer(server, sendPort);
  }
}
