import 'dart:async' show Completer, Future, FutureOr;
import 'dart:isolate' show Isolate, ReceivePort, RemoteError, SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;

final class IsolateSupervisor {
  IsolateSupervisor(
    this.multiIsolateServer,
    this.isolate,
    this.receivePort,
  ) : pendingMessageQueue = <MessageHubMessage>[];

  final MultiIsolateServer multiIsolateServer;

  final Isolate isolate;

  final ReceivePort receivePort;

  final List<MessageHubMessage> pendingMessageQueue;

  late SendPort serverSendPort;

  Completer<void>? launchCompleter;

  Completer<void>? reloadCompleter;

  Completer<void>? stopCompleter;

  void listener(Object? response) {
    if (response is SendPort) {
      serverSendPort = response;
      launchCompleter!.complete();
    } else if (response is int) {
      reloadCompleter!.complete();
    } else if (response == null) {
      receivePort.close();
      stopCompleter!.complete();
    } else if (response is List<Object> && response.length == 2) {
      var error = response[0];
      var stackTrace = response[1];

      if (stackTrace is StackTrace) {
        if (launchCompleter != null) {
          launchCompleter!.completeError(error, stackTrace);
        } else if (reloadCompleter != null) {
          reloadCompleter!.completeError(error, stackTrace);
        } else if (stopCompleter != null) {
          stopCompleter!.completeError(error, stackTrace);
        } else {
          Error.throwWithStackTrace(error, stackTrace);
        }
      } else {
        throw RemoteError('$error', '$stackTrace');
      }
    } else if (response is MessageHubMessage) {
      if (multiIsolateServer.isRunning) {
        sendMessageToOtherSupervisors(response);
      } else {
        pendingMessageQueue.add(response);
      }
    } else {
      // TODO(isolate): log unsupported response.
    }
  }

  void sendPendingMessages() {
    pendingMessageQueue
      ..forEach(sendMessageToOtherSupervisors)
      ..clear();
  }

  void sendMessageToOtherSupervisors(MessageHubMessage message) {
    for (var supervisor in multiIsolateServer.supervisors) {
      if (identical(this, supervisor)) {
        continue;
      }

      supervisor.serverSendPort.send(message);
    }
  }

  Future<void> resume() async {
    var completer = launchCompleter = Completer<void>();
    receivePort.listen(listener);
    isolate.resume(isolate.pauseCapability!);
    await completer.future;
    launchCompleter = null;
  }

  Future<void> reload() async {
    var completer = reloadCompleter = Completer<void>();
    serverSendPort.send(null);
    await completer.future;
    reloadCompleter = null;
  }

  Future<void> stop({bool force = false}) async {
    var completer = stopCompleter = Completer<void>();
    serverSendPort.send(force);
    await completer.future;
    isolate.kill();
    stopCompleter = null;
  }

  static Future<IsolateSupervisor> spawn(
    MultiIsolateServer multiIsolateServer,
    FutureOr<void> Function(SendPort?) spawn,
    int identifier,
  ) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(spawn, sendPort, //
        paused: true,
        onExit: sendPort,
        onError: sendPort,
        debugName: 'server/$identifier');

    return IsolateSupervisor(multiIsolateServer, isolate, receivePort);
  }
}

/// A [Server] that runs in multiple [Isolate]s.
final class MultiIsolateServer implements Server {
  /// Creates an instance of [MultiIsolateServer].
  MultiIsolateServer(this.url, this.logger)
      : supervisors = <IsolateSupervisor>[],
        isRunning = false;

  @override
  final Uri url;

  @override
  final Logger? logger;

  final List<IsolateSupervisor> supervisors;

  bool isRunning;

  Future<void> start(
    int isolates,
    Future<Server> Function(SendPort?) spawn,
  ) async {
    if (isRunning) {
      // TODO(isolate): update error message.
      throw StateError('Server is already running.');
    }

    try {
      for (var isolate = 0; isolate < isolates; isolate += 1) {
        var supervisor =
            await IsolateSupervisor.spawn(this, spawn, isolate + 1);
        supervisors.add(supervisor);
        await supervisor.resume();
      }

      for (var isolate = 0; isolate < isolates; isolate += 1) {
        supervisors[isolate].sendPendingMessages();
      }

      isRunning = true;
    } catch (error) {
      await close();
    }
  }

  /// Reloads [Application]s in all spawned [Isolate]s.
  Future<void> reload() async {
    Future<void> reload(IsolateSupervisor supervisor) async {
      await supervisor.reload();
    }

    await Future.wait<void>(supervisors.map<Future<void>>(reload));
  }

  @override
  Future<void> close({bool force = false}) async {
    Future<void> close(IsolateSupervisor supervisor) async {
      await supervisor.stop(force: force);
    }

    await Future.wait<void>(supervisors.map<Future<void>>(close));
    supervisors.clear();
    isRunning = false;
  }

  static Future<MultiIsolateServer> spawn(
    int isolates,
    Future<Server> Function(SendPort?) spawn, {
    required Uri url,
    Logger? logger,
  }) async {
    var multiIsolateServer = MultiIsolateServer(url, logger);
    await multiIsolateServer.start(isolates, spawn);
    return multiIsolateServer;
  }
}
