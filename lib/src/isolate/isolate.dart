import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/message.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.messagePort) : receivePort = RawReceivePort() {
    receivePort.handler = onMessage;
    messagePort.send(receivePort.sendPort);
  }

  final Server server;

  final SendPort messagePort;

  final RawReceivePort receivePort;

  @override
  Application? get application {
    return server.application;
  }

  @override
  InternetAddress get address {
    return server.address;
  }

  @override
  int get port {
    return server.port;
  }

  @override
  Uri get url {
    return server.url;
  }

  void onMessage(Object? message) {
    if (message != IsolateMessage.close) {
      // TODO: add error message
      throw UnsupportedError('');
    }

    close();
  }

  @override
  Future<void> mount(Application application) async {
    await server.mount(application);

    Future<ServiceExtensionResponse> reload(
      String isolateId,
      Map<String, String> data,
    ) async {
      try {
        await application.reload();
      } catch (error) {
        // TODO: log error
      }

      return ServiceExtensionResponse.result('{}');
    }

    registerExtension('ext.astra.reload', reload);
    messagePort.send(IsolateMessage.ready);
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    messagePort.send(IsolateMessage.closed);
  }
}
