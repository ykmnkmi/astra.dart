import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';

class IsolateServer extends IOServer {
  IsolateServer(this.sendPort, Handler handler, Object address, int port, //
      {SecurityContext? context,
      int backlog = 0,
      bool shared = false,
      bool v6Only = false,
      bool launch = false})
      : receivePort = ReceivePort(),
        super(handler, address, port, //
            context: context,
            backlog: backlog,
            shared: shared,
            v6Only: v6Only) {
    receivePort.listen(listener);
    sendPort.send(receivePort.sendPort);

    if (launch) {
      start();
    }
  }

  final SendPort sendPort;
  final ReceivePort receivePort;

  @override
  Future<void> start() async {
    await super.start();
    sendPort.send('listening');
  }

  @override
  Future<void> close() async {
    receivePort.close();
    await super.close();
    sendPort.send('stop');
  }

  Future<void> listener(Object? message) {
    if (message == 'stop') {
      return close();
    }

    throw UnimplementedError();
  }
}
