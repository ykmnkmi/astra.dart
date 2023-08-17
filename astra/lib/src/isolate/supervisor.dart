import 'dart:async' show Completer, Future, FutureOr;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;

import 'package:astra/src/isolate/message.dart';

class IsolateSupervisor {
  IsolateSupervisor(this.isolate, this.receivePort)
      : _launchCompleter = Completer<void>(),
        _stopCompleter = Completer<void>();

  final Isolate isolate;

  final ReceivePort receivePort;

  final Completer<void> _launchCompleter;

  final Completer<void> _stopCompleter;

  SendPort? _serverPort;

  Future<void> resume() async {
    if (_launchCompleter.isCompleted) {
      // TODO(isolate): update assert message
      assert(false, '');
      return;
    }

    void onMessage(Object? message) {
      if (message is SendPort) {
        _serverPort = message;
      } else if (message == IsolateMessage.ready) {
        _launchCompleter.complete();
      } else if (message == null) {
        receivePort.close();
        _stopCompleter.complete();
      } else if (message case [Object error, StackTrace stackTrace]) {
        _stopCompleter.completeError(error, stackTrace);
      } else {
        // TODO(isolate): update assert message
        assert(false, 'Unsupported message: $message');
      }
    }

    receivePort.listen(onMessage);
    isolate.resume(isolate.pauseCapability!);
    await _launchCompleter.future;
  }

  Future<void> stop({bool force = false}) async {
    var serverPort = _serverPort;

    if (serverPort == null) {
      // TODO(isolate): update error message
      throw StateError('');
    }

    if (_stopCompleter.isCompleted) {
      // TODO(isolate): update assert message
      assert(false, '');
      return;
    }

    if (force) {
      serverPort.send(IsolateMessage.closeForce);
    } else {
      serverPort.send(IsolateMessage.close);
    }

    await _stopCompleter.future;
  }

  Future<void> kill() async {
    isolate.kill();
    await _stopCompleter.future;
  }

  static Future<IsolateSupervisor> spawn(
    FutureOr<void> Function(SendPort) create, [
    String? debugName,
  ]) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(create, receivePort.sendPort,
        paused: true,
        onExit: sendPort,
        onError: sendPort,
        debugName: debugName);

    return IsolateSupervisor(isolate, receivePort);
  }
}
