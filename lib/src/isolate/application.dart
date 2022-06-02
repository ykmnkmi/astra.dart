import 'dart:developer';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/isolate.dart';

class ApplicationIsolateServer extends IsolateServer {
  /// @nodoc
  ApplicationIsolateServer(this.application, Server server, SendPort sendPort) : super(server, sendPort) {
    registerExtension('ext.astra.reload', reload);
  }

  final Application application;

  Future<ServiceExtensionResponse> reload(String isolateId, Map<String, String> data) async {
    try {
      application.reload();
      return ServiceExtensionResponse.result('{}');
    } catch (error) {
      return ServiceExtensionResponse.error(0, '$error');
    }
  }

  Future<void> start() async {
    await application.prepare();
    super.mount(application.entryPoint);
  }

  @override
  void mount(Handler handler) {
    throw UnsupportedError('not supported by ApplicationIsolateServer');
  }

  @override
  Future<void> close() async {
    await server.close();
    await application.close();
    sendPort.send('stop');
  }
}
