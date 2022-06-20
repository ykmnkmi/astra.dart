import 'dart:developer';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/src/isolate/isolate.dart';

class ApplicationServer extends IsolateServer {
  ApplicationServer(this.application, Server server, SendPort sendPort) : super(server, sendPort) {
    registerExtension('ext.astra.reload', reload);
  }

  final Application application;

  Future<ServiceExtensionResponse> reload(String isolateId, Map<String, String> data) async {
    try {
      application.reload();
      return ServiceExtensionResponse.result('{}');
    } catch (error) {
      return ServiceExtensionResponse.error(ServiceExtensionResponse.extensionError, '$error');
    }
  }

  Future<void> start() async {
    await application.prepare();
    mount(application.entryPoint);
  }

  @override
  Future<void> close({bool force = false}) async {
    await application.close();
    return super.close(force: force);
  }
}
