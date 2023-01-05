import 'dart:async';
import 'dart:io' show InternetAddress;
import 'dart:isolate' show RawReceivePort, ReceivePort, SendPort;

import 'package:astra/core.dart';
import 'package:astra/src/isolate/message.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.controlPort)
      : receivePort = ReceivePort(),
        completer = Completer<void>() {
    receivePort.listen(onMessage);
    controlPort.send(receivePort.sendPort);
  }

  final Server server;

  final SendPort controlPort;

  final ReceivePort receivePort;

  /// The underlying `done` [Completer].
  final Completer<void> completer;

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
    return completer.future;
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
    if (completer.isCompleted) {
      // TODO(isolate): add error message
      throw StateError('');
    }

    try {
      await server.close(force: force);
      controlPort.send(IsolateMessage.closed);
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    }
  }
}
