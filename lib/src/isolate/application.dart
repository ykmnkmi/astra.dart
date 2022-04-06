import 'dart:developer';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/isolate.dart';

class ApplicationIsolateServer extends IsolateServer {
  ApplicationIsolateServer(this.application, Server server, SendPort sendPort)
      : super(server, sendPort) {
    registerExtension('ext.astra.reload', (isolateId, data) async {
      try {
        application.onReload();
        return ServiceExtensionResponse.result('{}');
      } catch (error) {
        return ServiceExtensionResponse.error(0, '$error');
      }
    });
  }

  final Application application;

  Future<void> start() async {
    await application.prepare();
    mount(application.entryPoint);
  }

  @override
  Future<void> close() async {
    await super.close();
    await application.onClose();
  }
}
