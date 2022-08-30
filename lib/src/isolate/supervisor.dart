import 'dart:async';
import 'dart:isolate';

import 'package:astra/src/isolate/message.dart';
import 'package:logging/logging.dart';

class IsolateSupervisor {
  IsolateSupervisor(this.isolate, this.receive) : logger = Logger(isolate.debugName!);

  final Isolate isolate;

  final RawReceivePort receive;

  final Logger logger;

  SendPort? server;

  Completer<void>? launchCompleter;

  Completer<void>? stopCompleter;

  void listener(Object? message) {
    if (message is SendPort) {
      server = message;
      return;
    }

    if (message == IsolateMessage.ready) {
      launchCompleter!.complete();
      launchCompleter = null;
      // TODO: translate log message
      logger.fine('${isolate.debugName} запущен.');
      return;
    }

    if (message == IsolateMessage.closed) {
      receive.close();
      stopCompleter!.complete();
      stopCompleter = null;
      // TODO: translate log message
      logger.fine('${isolate.debugName} завершился.');
      return;
    }

    if (message is List<String>) {
      var error = message[0];
      var trace = StackTrace.fromString(message[1]);

      if (launchCompleter != null) {
        launchCompleter!.completeError(error, trace);
      } else if (stopCompleter != null) {
        // TODO: translate log message
        logger.severe('${isolate.debugName} завершился с иключение.', error, trace);
        receive.close();
      } else {
        logger.severe('Uncaught exception in ${isolate.debugName}.', error, trace);
      }
    }
  }

  Future<void> resume() {
    if (launchCompleter != null) {
      // TODO: add error message
      throw StateError('');
    }

    launchCompleter = Completer<void>();
    receive.handler = listener;
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
