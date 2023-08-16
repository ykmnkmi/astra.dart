import 'dart:async' show Completer, Future, FutureOr;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;

import 'package:astra/src/isolate/message.dart';

class IsolateSupervisor {
  IsolateSupervisor(this.isolate, this.receivePort)
      : launchCompleter = Completer<void>(),
        stopCompleter = Completer<void>();

  final Isolate isolate;

  final ReceivePort receivePort;

  SendPort? serverPort;

  Completer<void> launchCompleter;

  Completer<void> stopCompleter;

  void onMessage(Object? message) {
    if (message is SendPort) {
      serverPort = message;
      return;
    }

    if (message == IsolateMessage.ready) {
      launchCompleter.complete();
      return;
    }

    if (message == null) {
      receivePort.close();
      stopCompleter.complete();
      return;
    }

    if (message is List && message.length == 2) {
      var error = message[0];
      var stackTrace = message[1];

      if (error is Object && stackTrace is StackTrace) {
        stopCompleter.completeError(error, stackTrace);
        return;
      }
    }

    // TODO(isolate): update error message
    throw UnsupportedError('');
  }

  Future<void> resume() async {
    if (launchCompleter.isCompleted) {
      // TODO(isolate): update error message
      throw StateError('');
    }

    receivePort.listen(onMessage);
    isolate.resume(isolate.pauseCapability!);
    await launchCompleter.future;
  }

  Future<void> stop({bool force = false}) async {
    var serverPort = this.serverPort;

    if (serverPort == null) {
      // TODO(isolate): update error message
      throw StateError('');
    }

    if (stopCompleter.isCompleted) {
      // TODO(isolate): update error message
      throw StateError('');
    }

    if (force) {
      serverPort.send(IsolateMessage.closeForce);
    } else {
      serverPort.send(IsolateMessage.close);
    }

    await stopCompleter.future;
  }

  Future<void> kill() async {
    isolate.kill();
    await stopCompleter.future;
  }

  static Future<IsolateSupervisor> spawn(
    FutureOr<void> Function(SendPort) create, [
    String? debugName,
  ]) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(
      create,
      receivePort.sendPort,
      paused: true,
      onExit: sendPort,
      onError: sendPort,
      debugName: debugName,
    );

    return IsolateSupervisor(isolate, receivePort);
  }
}
