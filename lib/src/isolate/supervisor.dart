import 'dart:async';
import 'dart:isolate';

class IsolateSupervisor {
  IsolateSupervisor(this.isolate, this.receive, this.identifier);

  final Isolate isolate;

  final RawReceivePort receive;

  final int identifier;

  late SendPort server;

  Completer<void>? launchCompleter;

  Completer<void>? stopCompleter;

  void listener(Object? message) {
    if (message is SendPort) {
      server = message;
      return;
    }

    if (message == 'listening') {
      launchCompleter!.complete();
      launchCompleter = null;
      return;
    }

    if (message == 'stop') {
      receive.close();
      stopCompleter!.complete();
      stopCompleter = null;
      return;
    }

    if (message is List<Object>) {
      var trace = StackTrace.fromString(message[1] as String);

      if (launchCompleter != null) {
        launchCompleter!.completeError(message[0], trace);
      }

      if (stopCompleter != null) {
        stopCompleter!.completeError(message[0], trace);
      }
    }
  }

  Future<void> resume() async {
    launchCompleter = Completer<void>();
    receive.handler = listener;
    isolate.resume(isolate.pauseCapability!);
    return launchCompleter!.future;
  }

  Future<void> stop() async {
    stopCompleter = Completer();
    server.send('stop');
    await stopCompleter!.future;
    receive.close();
  }
}
