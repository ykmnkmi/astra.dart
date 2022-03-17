import 'dart:async';
import 'dart:isolate';

class IsolateSupervisor {
  IsolateSupervisor(this.script, this.name);

  final Uri script;

  final String name;

  late Isolate isolate;

  late ReceivePort receive;

  SendPort? server;

  Completer<void>? launchCompleter;

  Completer<void>? stopCompleter;

  Future<void> start() async {
    if (server != null) {
      // TODO: update error
      throw StateError('supervisor: stop before start');
    }

    launchCompleter = Completer<void>();
    receive = ReceivePort();
    receive.listen(listener);

    isolate = await Isolate.spawnUri(script, <String>[], receive.sendPort, //
        onError: receive.sendPort,
        errorsAreFatal: false,
        debugName: name);

    return launchCompleter!.future;
  }

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
      stopCompleter?.complete();
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

  Future<void> stop() async {
    stopCompleter = Completer();
    server!.send('stop');
    await stopCompleter!.future;
    receive.close();
  }
}
