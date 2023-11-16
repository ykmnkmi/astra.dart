import 'dart:async' show Future, StreamController, StreamSubscription;
import 'dart:isolate' show ReceivePort, SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/servers/h11.dart';

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

base class IsolateServer extends H11Server {
  IsolateServer(
    SendPort sendPort,
    super.address,
    super.port, {
    super.securityContext,
    super.backlog,
    super.v6Only,
    super.requestClientCertificate,
    super.shared,
    super.identifier,
    super.logger,
  })  : _sendPort = sendPort,
        _receivePort = ReceivePort(),
        _messageHub = _MessageHub(sendPort) {
    _receivePort.listen(_listener);
  }

  final SendPort _sendPort;

  final ReceivePort _receivePort;

  final _MessageHub _messageHub;

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
    if (application case var mountedApplication?) {
      await mountedApplication.reload();
    }

    _sendPort.send(true);
  }

  @override
  Future<void> mount(Application application) async {
    application.messageHub = _messageHub;
    await super.mount(application);
    _sendPort.send(_receivePort.sendPort);
  }

  @override
  Future<void> close({bool force = false}) async {
    await super.close(force: force);
    await _messageHub.close();
    _receivePort.close();
  }
}
