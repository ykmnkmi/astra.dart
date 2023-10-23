import 'dart:async' show Completer, Future, FutureOr, TimeoutException;
import 'dart:isolate' show Isolate, ReceivePort, RemoteError, SendPort;

import 'package:astra/src/isolate/isolate_server.dart';
import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/server.dart';

abstract class SupervisorManager {
  SupervisorManager()
      : _supervisors = <IsolateSupervisor>[],
        _isRunning = false;

  final List<IsolateSupervisor> _supervisors;

  bool get isRunning {
    return _isRunning;
  }

  bool _isRunning;

  Future<void> start(
    int isolates,
    Future<Server> Function(SendPort sendPort) spawn,
  ) async {
    for (var index = 0; index < isolates; index += 1) {
      var supervisor = await IsolateSupervisor.spawn(this, spawn, index + 1);
      _supervisors.add(supervisor);
    }

    for (var currentSupervisor in _supervisors) {
      currentSupervisor.sendPendingMessages();
    }

    _isRunning = true;
  }

  Future<void> stop({bool force = false}) async {
    Future<void> close(IsolateSupervisor supervisor) async {
      await supervisor.stop(force: force);
    }

    var futures = _supervisors.map<Future<void>>(close);
    await Future.wait<void>(futures);
  }
}

/// Represents the supervision of a [IsolateServer].
class IsolateSupervisor {
  IsolateSupervisor(
    this.supervisorManager,
    this.isolate,
    this.receivePort,
  ) : _pendingMessageQueue = <MessageHubMessage>[] {
    _launchCompleter = Completer<SendPort>();
    _launchCompleter!.future
        .timeout(const Duration(seconds: 10))
        .then<void>(_bindServerSendPort);

    receivePort.listen(_listener);
    isolate.resume(isolate.pauseCapability!);
  }

  final SupervisorManager supervisorManager;

  /// The [Isolate] being supervised.
  final Isolate isolate;

  /// The [ReceivePort] for which messages coming from [isolate] will be received.
  final ReceivePort receivePort;

  late SendPort _serverControlPort;

  final List<MessageHubMessage> _pendingMessageQueue;

  Completer<SendPort>? _launchCompleter;

  Completer<void>? _stopCompleter;

  void _bindServerSendPort(SendPort sendPort) {
    _serverControlPort = sendPort;
  }

  void _listener(Object? value) {
    switch (value) {
      case null: // on exit or stop
        receivePort.close();
        _stopCompleter!.complete();
        _stopCompleter = null;
        break;

      case MessageHubMessage message:
        if (supervisorManager.isRunning) {
          _sendMessage(message);
        } else {
          _pendingMessageQueue.add(message);
        }

        break;

      case SendPort sendPort:
        _launchCompleter!.complete(sendPort);
        _launchCompleter = null;
        break;

      case [Object error, StackTrace stackTrace]:
        if (_launchCompleter case var completer?) {
          completer.completeError(error, stackTrace);
        } else if (_stopCompleter case var completer?) {
          completer.completeError(error, stackTrace);
        } else {
          throw RemoteError('$error', '$stackTrace');
        }

        break;

      default:
        assert(false, 'Unreachable.');
    }
  }

  void _sendMessage(MessageHubMessage message) {
    for (var supervisor in supervisorManager._supervisors) {
      if (!identical(supervisor, this)) {
        supervisor._serverControlPort.send(message);
      }
    }
  }

  void sendPendingMessages() {
    _pendingMessageQueue.forEach(_sendMessage);
    _pendingMessageQueue.clear();
  }

  Future<void> stop({bool force = false}) async {
    _stopCompleter = Completer<void>();
    _serverControlPort.send(force);

    try {
      await _stopCompleter!.future.timeout(const Duration(seconds: 10));
      _stopCompleter = null;
    } on TimeoutException {
      isolate.kill();
    }
  }

  static Future<IsolateSupervisor> spawn(
    SupervisorManager supervisorManager,
    FutureOr<void> Function(SendPort) create,
    int identifier,
  ) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(create, sendPort,
        paused: true,
        onExit: sendPort,
        onError: sendPort,
        debugName: 'server/$identifier');

    return IsolateSupervisor(supervisorManager, isolate, receivePort);
  }
}
