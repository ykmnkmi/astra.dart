import 'dart:async' show Completer, Future;
import 'dart:io' show InternetAddress;
import 'dart:isolate' show ReceivePort, SendPort;

import 'package:astra/core.dart';
import 'package:astra/src/isolate/message.dart';
import 'package:astra/src/serve/server.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.controlPort)
      : receivePort = ReceivePort(),
        doneCompleter = Completer<void>() {
    receivePort.listen(onMessage);
    controlPort.send(receivePort.sendPort);
  }

  final Server server;

  final SendPort controlPort;

  final ReceivePort receivePort;

  /// The underlying `done` [Completer].
  final Completer<void> doneCompleter;

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
    return doneCompleter.future;
  }

  void onMessage(Object? message) {
    switch (message) {
      case IsolateMessage.close:
        close();
        break;
      case IsolateMessage.closeForce:
        close(force: true);
        break;
      default:
        // TODO(isolate): update error message
        throw UnsupportedError('');
    }
  }

  @override
  Future<void> mount(Application application) async {
    await server.mount(application);
    controlPort.send(IsolateMessage.ready);
  }

  @override
  Future<void> close({bool force = false}) async {
    if (doneCompleter.isCompleted) {
      // TODO(isolate): update error message
      throw StateError('');
    }

    try {
      await server.close(force: force);
      doneCompleter.complete();
      receivePort.close();
    } catch (error, stackTrace) {
      doneCompleter.completeError(error, stackTrace);
      rethrow;
    }
  }
}
