import 'dart:async';
import 'dart:isolate';

import 'package:astra/src/isolate/isolate.dart';
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

    if (message == IsolateServer.readyMessage) {
      launchCompleter!.complete();
      launchCompleter = null;
      // TODO: translate
      logger.fine('$identifier запущен.');
      return;
    }

    if (message == IsolateServer.closedMessage) {
      receive.close();
      stopCompleter!.complete();
      stopCompleter = null;
      // TODO: translate
      logger.fine('$identifier завершился.');
      return;
    }

    if (message is List<String>) {
      final error = message[0];
      final trace = StackTrace.fromString(message[1]);

      if (launchCompleter != null) {
        launchCompleter!.completeError(error, trace);
      } else if (stopCompleter != null) {
        // TODO: translate
        logger.severe('$identifier завершился с иключение.', error, trace);
        receive.close();
      } else {
        logger.severe('Uncaught exception in $identifier.', error, trace);
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
    stopCompleter = Completer();
    server.send(IsolateServer.closeMessage);
    await stopCompleter!.future;
  }
}
