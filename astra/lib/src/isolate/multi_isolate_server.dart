import 'dart:async' show Completer, Future, FutureOr;
import 'dart:isolate' show Isolate, ReceivePort, RemoteError, SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;

/// Manages a single isolate running a server instance within a multi-isolate setup.
///
/// Handles communication between the main isolate and worker isolates, manages
/// the isolate lifecycle, and facilitates message passing between isolates.
final class IsolateSupervisor {
  /// Creates an [IsolateSupervisor] for the given isolate and communication ports.
  IsolateSupervisor(this.multiIsolateServer, this.isolate, this.receivePort)
    : pendingMessageQueue = <MessageHubMessage>[];

  /// The parent [MultiIsolateServer] managing this supervisor.
  final MultiIsolateServer multiIsolateServer;

  /// The [Isolate] being supervised.
  final Isolate isolate;

  /// Port for receiving messages from the supervised isolate.
  final ReceivePort receivePort;

  /// Queue for messages received before all isolates are fully started.
  final List<MessageHubMessage> pendingMessageQueue;

  /// Port for sending messages to the supervised isolate's server.
  late SendPort serverSendPort;

  /// Completer for isolate launch operations.
  Completer<void>? launchCompleter;

  /// Completer for server reload operations.
  Completer<void>? reloadCompleter;

  /// Completer for isolate stop operations.
  Completer<void>? stopCompleter;

  /// Handles messages received from the supervised isolate.
  ///
  /// Message types:
  /// - [SendPort]: [Server]'s send port, completes launch
  /// - [int]: Reload completion signal (0 = success)
  /// - `null`: Isolate exit signal, completes stop operation
  /// - [List<Object>] with 2 elements: error and stack trace
  /// - [MessageHubMessage]: Inter-isolate message to broadcast
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
      assert(false, 'Unsupported message: ${response.runtimeType} $response');
    }
  }

  /// Sends all queued messages to other supervisors once the server is running.
  void sendPendingMessages() {
    pendingMessageQueue
      ..forEach(sendMessageToOtherSupervisors)
      ..clear();
  }

  /// Broadcasts a message to all other supervised isolates.
  void sendMessageToOtherSupervisors(MessageHubMessage message) {
    for (var supervisor in multiIsolateServer.supervisors) {
      if (identical(this, supervisor)) {
        continue;
      }

      supervisor.serverSendPort.send(message);
    }
  }

  /// Resumes the paused isolate and waits for it to send its server port.
  Future<void> resume() async {
    var completer = launchCompleter = Completer<void>();
    receivePort.listen(listener);
    isolate.resume(isolate.pauseCapability!);
    await completer.future;
    launchCompleter = null;
  }

  /// Requests the supervised isolate to reload its application.
  Future<void> reload() async {
    var completer = reloadCompleter = Completer<void>();
    serverSendPort.send(null);
    await completer.future;
    reloadCompleter = null;
  }

  /// Stops the supervised isolate.
  ///
  /// If [force] is true, performs a forceful shutdown.
  Future<void> stop({bool force = false}) async {
    var completer = stopCompleter = Completer<void>();
    serverSendPort.send(force);
    await completer.future;
    isolate.kill();
    stopCompleter = null;
  }

  /// Spawns a new isolate with a supervisor to manage it.
  ///
  /// The isolate is created in a paused state and must be resumed manually.
  /// The [identifier] is used for debugging purposes in the isolate name.
  static Future<IsolateSupervisor> spawn(
    MultiIsolateServer multiIsolateServer,
    FutureOr<void> Function(SendPort?) spawn,
    int identifier,
  ) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(
      spawn,
      sendPort,
      paused: true,
      onExit: sendPort,
      onError: sendPort,
      debugName: 'server/$identifier',
    );

    return IsolateSupervisor(multiIsolateServer, isolate, receivePort);
  }
}

/// A [Server] that distributes incoming requests across multiple [Isolate]s
/// for improved performance and resource utilization.
///
/// Each isolate runs its own server instance, and incoming connections are
/// automatically distributed by the underlying operating system when using
/// shared socket binding.
final class MultiIsolateServer implements Server {
  /// Creates a [MultiIsolateServer] with the specified URL and logger.
  ///
  /// The server is not running until [start] is called.
  MultiIsolateServer(this.url, this.logger)
    : supervisors = <IsolateSupervisor>[],
      isRunning = false;

  @override
  final Uri url;

  @override
  final Logger? logger;

  /// List of supervisors managing individual isolate instances.
  final List<IsolateSupervisor> supervisors;

  /// Whether the multi-isolate server is currently running.
  bool isRunning;

  /// Starts the specified number of isolates, each running a server instance.
  ///
  /// All isolates are created and started before the server is marked as running.
  /// If any isolate fails to start, all isolates are shut down.
  Future<void> start(
    int isolates,
    Future<Server> Function(SendPort?) spawn,
  ) async {
    if (isRunning) {
      throw StateError('MultiIsolateServer is already running.');
    }

    try {
      for (var isolate = 0; isolate < isolates; isolate += 1) {
        var supervisor = await IsolateSupervisor.spawn(
          this,
          spawn,
          isolate + 1,
        );

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

  /// Reloads [Application]s in all spawned [Isolate]s concurrently.
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

  /// Creates and starts a new [MultiIsolateServer] with the specified configuration.
  ///
  /// This is a convenience method that combines instantiation and startup.
  /// The [url] should match the URL that the individual server instances will bind to.
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
