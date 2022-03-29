import 'dart:async';
import 'dart:isolate';

class IsolateSupervisor {
  IsolateSupervisor(this.create, this.name);

  final FutureOr<void> Function(SendPort sendPort) create;

  final String name;

  late Isolate isolate;

  late RawReceivePort receive;

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

  Future<void> init() async {
    launchCompleter = Completer<void>();
    receive = RawReceivePort();
    receive.handler = listener;
    isolate = await Isolate.spawn<SendPort>(create, receive.sendPort, //
        errorsAreFatal: false,
        onError: receive.sendPort,
        debugName: name);
    return launchCompleter!.future;
  }

  Future<void> stop() async {
    stopCompleter = Completer();
    server.send('stop');
    await stopCompleter!.future;
    receive.close();
  }
}
