library astra.server.isolate.server;

import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/message.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class IsolateServer implements Server {
  IsolateServer(this.server, this.messagePort)
      : receivePort = RawReceivePort(),
        mounted = false {
    receivePort.handler = onMessage;
    messagePort.send(receivePort.sendPort);
  }

  @internal
  final Server server;

  @internal
  final SendPort messagePort;

  @internal
  final RawReceivePort receivePort;

  bool mounted;

  @override
  InternetAddress get address {
    return server.address;
  }

  @override
  int get port {
    return server.port;
  }

  // TODO: catch error
  void onMessage(Object? message) {
    if (message == IsolateMessage.close) {
      close();
      return;
    }

    // TODO: add error message
    throw UnsupportedError('');
  }

  // TODO: catch error
  @override
  Future<void> mount(Application application, [Logger? logger]) async {
    if (mounted) {
      // TODO: add error message
      throw StateError('');
    }

    mounted = true;
    await application.prepare();

    Future<ServiceExtensionResponse> reload(String isolateId, Map<String, String> data) async {
      try {
        await application.reload();
      } catch (error) {
        // TODO: log error
      }

      return ServiceExtensionResponse.result('{}');
    }

    registerExtension('ext.astra.reload', reload);
    await server.mount(application, logger);
    messagePort.send(IsolateMessage.ready);
  }

  // TODO: add error message
  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);
    messagePort.send(IsolateMessage.closed);
  }
}
