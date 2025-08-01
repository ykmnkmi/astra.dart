import 'dart:async' show Future, StreamController, StreamSubscription;
import 'dart:io' show SecurityContext;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/isolate/message_hub_message.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/type.dart';
import 'package:logging/logging.dart' show Logger;

/// Current [Isolate] debug name.
String get isolateName => Isolate.current.debugName ?? 'isolate';

/// A [MessageHub] that runs in an [Isolate].
final class IsolateMessageHub extends Stream<Object?> implements MessageHub {
  /// Creates an instance of [IsolateMessageHub].
  IsolateMessageHub(this.sendPort)
    : inbound = StreamController<Object?>.broadcast();

  /// The [SendPort] to send messages to.
  final SendPort sendPort;

  /// The [StreamController] to receive messages from.
  final StreamController<Object?> inbound;

  /// Sends a message to the [sendPort].
  void sendMessage(Object? value) {
    try {
      sendPort.send(MessageHubMessage(value));
    } catch (error, stackTrace) {
      inbound.sink.addError(error, stackTrace);
    }
  }

  @override
  void add(Object? event) {
    sendMessage(event);
  }

  @override
  StreamSubscription<Object?> listen(
    void Function(Object? event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return inbound.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<void> close() async {
    if (!inbound.hasListener) {
      inbound.stream.drain<void>();
    }

    await inbound.close();
  }
}

final class IsolateServer implements Server {
  IsolateServer(this.server, this.sendPort) : receivePort = ReceivePort() {
    receivePort.listen(listener);
    logger?.fine('$isolateName listening, sending port.');
    sendPort.send(receivePort.sendPort);
  }

  final Server server;

  final SendPort sendPort;

  final ReceivePort receivePort;

  @override
  Uri get url => server.url;

  @override
  Logger? get logger => server.logger;

  void listener(Object? value) {
    if (value is bool) {
      close(force: value);
    } else {
      logger?.warning('$isolateName received unsupported message: $value');
    }
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    receivePort.close();
  }

  static Future<IsolateServer> bind(
    SendPort sendPort,
    Handler handler,
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    Logger? logger,
  }) async {
    var server = await Server.bind(
      handler,
      address,
      port,
      securityContext: securityContext,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
      logger: logger,
      type: type,
    );

    return IsolateServer(server, sendPort);
  }
}

final class ApplicationIsolateServer
    implements ApplicationServer, IsolateServer {
  ApplicationIsolateServer(this.server, this.sendPort)
    : receivePort = ReceivePort(),
      messageHub = IsolateMessageHub(sendPort) {
    receivePort.listen(listener);
    logger?.fine('$isolateName listening, sending port.');
    sendPort.send(receivePort.sendPort);
  }

  @override
  final ApplicationServer server;

  @override
  final SendPort sendPort;

  @override
  final ReceivePort receivePort;

  final IsolateMessageHub messageHub;

  @override
  Application get application => server.application;

  @override
  Uri get url => server.url;

  @override
  Logger? get logger => server.logger;

  @override
  void listener(Object? value) {
    if (value == null) {
      reload();
    } else if (value is MessageHubMessage) {
      messageHub.inbound.sink.add(value.value);
    } else if (value is bool) {
      close(force: value);
    } else {
      logger?.warning('$isolateName received unsupported message: $value');
    }
  }

  @override
  Future<void> reload() async {
    try {
      await server.reload();
      sendPort.send(0);
    } catch (error, stackTrace) {
      sendPort.send(<Object>[error, stackTrace]);
    }
  }

  @override
  Future<void> close({bool force = false}) async {
    try {
      await server.close(force: force);
      await messageHub.close();
    } catch (error, stackTrace) {
      sendPort.send(<Object>[error, stackTrace]);
    }

    receivePort.close();
  }

  static Future<ApplicationIsolateServer> bind(
    SendPort sendPort,
    Application application,
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
    ServerType type = ServerType.defaultType,
    Logger? logger,
  }) async {
    var server = await ApplicationServer.bind(
      application,
      address,
      port,
      securityContext: securityContext,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
      type: type,
      logger: logger,
    );

    return ApplicationIsolateServer(server, sendPort);
  }
}
