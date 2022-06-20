import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

class IsolateSupervisor {
  IsolateSupervisor(this.isolate, this.receive, this.identifier) : logger = Logger('isolate/$identifier');

  final Isolate isolate;

  final RawReceivePort receive;

  final int identifier;

  final Logger logger;

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
      // TODO(message): translate
      logger.fine('$identifier запущен.');
      return;
    }

    if (message == 'stop') {
      receive.close();
      stopCompleter!.complete();
      stopCompleter = null;
      // TODO(message): translate
      logger.fine('$identifier завершился.');
      return;
    }

    if (message is List<Object?>) {
      var error = message[0] as Object;
      var trace = message[1] as StackTrace;

      if (launchCompleter != null) {
        launchCompleter!.completeError(error, trace);
      } else if (stopCompleter != null) {
        // TODO(message): translate
        logger.severe('$identifier завершился с иключение.', error, trace);
        receive.close();
      } else {
        logger.severe('Uncaught exception in $identifier.', error, trace);
      }
    }
  }

  Future<void> resume() {
    launchCompleter = Completer<void>();
    receive.handler = listener;
    isolate.resume(isolate.pauseCapability!);
    return launchCompleter!.future;
  }

  Future<void> stop() async {
    stopCompleter = Completer();
    server.send('stop');
    await stopCompleter!.future;
  }
}
