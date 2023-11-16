import 'dart:async' show Completer, Future, FutureOr;
import 'dart:isolate' show Isolate, ReceivePort, RemoteError, SendPort;

import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/server.dart';

final class SupervisorManager {
  SupervisorManager()
      : _supervisors = <IsolateSupervisor>[],
        _isRunning = false;

  final List<IsolateSupervisor> _supervisors;

  bool _isRunning;

  bool get isRunning {
    return _isRunning;
  }

  Future<void> start(
    int isolates,
    Future<Server> Function(SendPort sendPort) spawn,
  ) async {
    try {
      for (var index = 0; index < isolates; index += 1) {
        var supervisor = await IsolateSupervisor.spawn(this, spawn, index + 1);
        _supervisors.add(supervisor);
      }
    } catch (error) {
      await stop();
      rethrow;
    }

    for (var currentSupervisor in _supervisors) {
      currentSupervisor.sendPendingMessages();
    }

    _isRunning = true;
  }

  Future<void> reload() async {
    Future<void> reload(IsolateSupervisor supervisor) async {
      await supervisor.reload();
    }

    await Future.wait<void>(_supervisors.map<Future<void>>(reload));
  }

  Future<void> stop({bool force = false}) async {
    Future<void> close(IsolateSupervisor supervisor) {
      return supervisor.stop(force: force);
    }

    await Future.wait<void>(_supervisors.map<Future<void>>(close));
    _supervisors.clear();
    _isRunning = false;
  }
}

final class IsolateSupervisor {
  IsolateSupervisor(
    this.supervisorManager,
    this.isolate,
    this.receivePort,
  ) : _pendingMessageQueue = <MessageHubMessage>[] {
    _launchCompleter = Completer<SendPort>();
    _launchCompleter!.future.then<void>(_bindServerSendPort);
    receivePort.listen(_listener);
    isolate.resume(isolate.pauseCapability!);
  }

  final SupervisorManager supervisorManager;

  final Isolate isolate;

  final ReceivePort receivePort;

  final List<MessageHubMessage> _pendingMessageQueue;

  late SendPort _serverControlPort;

  Completer<SendPort>? _launchCompleter;

  Completer<void>? _reloadCompleter;

  Completer<void>? _stopCompleter;

  void _listener(Object? value) {
    switch (value) {
      case MessageHubMessage message: // on hub message
        if (supervisorManager.isRunning) {
          _sendMessage(message);
        } else {
          _pendingMessageQueue.add(message);
        }

        break;

      case SendPort sendPort: // on start
        _launchCompleter!.complete(sendPort);
        _launchCompleter = null;
        break;

      case bool(): // on reload
        _reloadCompleter!.complete();
        _reloadCompleter = null;
        break;

      case null: // on exit or stop
        receivePort.close();
        _stopCompleter!.complete();
        _stopCompleter = null;
        break;

      case <Object?>[Object error, Object stackTrace]: // on error
        if (stackTrace is StackTrace) {
          if (_launchCompleter case var completer?) {
            completer.completeError(error, stackTrace);
          } else if (_reloadCompleter case var completer?) {
            completer.completeError(error, stackTrace);
          } else if (_stopCompleter case var completer?) {
            completer.completeError(error, stackTrace);
          } else {
            Error.throwWithStackTrace(error, stackTrace);
          }
        } else {
          throw RemoteError('$error', '$stackTrace');
        }

        break;

      default:
        assert(false, 'Unreachable.');
    }
  }

  void _bindServerSendPort(SendPort sendPort) {
    _serverControlPort = sendPort;
  }

  Future<void> reload() {
    _reloadCompleter = Completer<void>();
    _serverControlPort.send(null);
    return _reloadCompleter!.future;
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
    await _stopCompleter!.future;
    _stopCompleter = null;
  }

  static Future<IsolateSupervisor> current(
    SupervisorManager supervisorManager,
    FutureOr<void> Function(SendPort) create,
    int identifier,
  ) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(create, sendPort,
        onExit: sendPort, onError: sendPort, debugName: 'server/$identifier');

    return IsolateSupervisor(supervisorManager, isolate, receivePort);
  }

  static Future<IsolateSupervisor> spawn(
    SupervisorManager supervisorManager,
    FutureOr<void> Function(SendPort) create,
    int identifier,
  ) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;

    var isolate = await Isolate.spawn<SendPort>(create, sendPort,
        onExit: sendPort, onError: sendPort, debugName: 'server/$identifier');

    return IsolateSupervisor(supervisorManager, isolate, receivePort);
  }
}
