import 'dart:async' show Completer, Future;
import 'dart:isolate' show Isolate, RawReceivePort, SendPort;

import 'package:astra/src/isolate/message.dart';

class IsolateSupervisor {
  IsolateSupervisor(this.isolate, this.receive);

  final Isolate isolate;

  final RawReceivePort receive;

  SendPort? server;

  Completer<void>? launchCompleter;

  Completer<void>? stopCompleter;

  void onMessage(Object? message) {
    if (message is SendPort) {
      server = message;
      return;
    }

    if (message == IsolateMessage.ready) {
      launchCompleter!.complete();
      launchCompleter = null;
      return;
    }

    if (message == IsolateMessage.closed) {
      receive.close();
      stopCompleter!.complete();
      stopCompleter = null;
      return;
    }
  }

  Future<void> resume() {
    if (launchCompleter != null) {
      // TODO: add error message
      throw StateError('');
    }

    launchCompleter = Completer<void>();
    receive.handler = onMessage;
    isolate.resume(isolate.pauseCapability!);
    return launchCompleter!.future;
  }

  Future<void> stop() async {
    if (server == null) {
      // TODO: add error message
      throw StateError('');
    }

    stopCompleter = Completer();
    server!.send(IsolateMessage.close);
    await stopCompleter!.future;
  }
}
