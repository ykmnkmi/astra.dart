import 'dart:async' show Future, StreamController, StreamSubscription;
import 'dart:isolate' show ReceivePort, SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;

final class _MessageHub extends Stream<Object?> implements MessageHub {
  _MessageHub(this._sendPort)
      : _inbound = StreamController<Object?>.broadcast();

  final SendPort _sendPort;

  final StreamController<Object?> _inbound;

  void _sendMessage(Object? value) {
    try {
      _sendPort.send(MessageHubMessage(value));
    } catch (error, stackTrace) {
      _inbound.sink.addError(error, stackTrace);
    }
  }

  @override
  void add(Object? event) {
    _sendMessage(event);
  }

  @override
  StreamSubscription<Object?> listen(
    void Function(Object? event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _inbound.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future<void> close() async {
    if (!_inbound.hasListener) {
      _inbound.stream.drain<void>();
    }

    await _inbound.close();
  }
}

final class IsolateServer implements Server {
  IsolateServer(Server server, SendPort sendPort)
      : _server = server,
        _sendPort = sendPort,
        _receivePort = ReceivePort(),
        _messageHub = _MessageHub(sendPort) {
    _receivePort.listen(_listener);
  }

  final Server _server;

  final SendPort _sendPort;

  final ReceivePort _receivePort;

  final _MessageHub _messageHub;

  @override
  Application? get application => _server.application;

  @override
  Logger get logger => Logger('astra');

  @override
  Uri get url => _server.url;

  @override
  Future<void> get done => _server.done;

  void _listener(Object? value) {
    switch (value) {
      case MessageHubMessage message:
        _messageHub._inbound.sink.add(message.value);
        break;
      case null:
        _reload();
        break;
      case bool force:
        close(force: force);
        break;
      default:
        assert(false, 'Unreachable.');
    }
  }

  Future<void> _reload() async {
    if (_server.application case var application?) {
      await application.reload();
    }

    _sendPort.send(true);
  }

  @override
  Future<void> mount(Application application) async {
    application.messageHub = _messageHub;
    await _server.mount(application);
    _sendPort.send(_receivePort.sendPort);
  }

  @override
  Future<void> close({bool force = false}) async {
    await _server.close(force: force);
    await _messageHub.close();
    _receivePort.close();
  }
}
