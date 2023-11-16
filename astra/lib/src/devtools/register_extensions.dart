import 'dart:developer' show ServiceExtensionResponse, registerExtension;

import 'package:astra/src/isolate/multi_isolate_server.dart';
import 'package:astra/src/serve/server.dart';

/// Registers useful extensions for the CLI and Dart DevTools.
void registerExtensions(Server server) {
  // TODO(devtools): Handle errors.
  Future<ServiceExtensionResponse> reload(
    String method,
    Map<String, String> parameters,
  ) async {
    if (server is MultiIsolateServer) {
      await server.reload();
    } else if (server.application case var application?) {
      await application.reload();
    }

    return ServiceExtensionResponse.result('{}');
  }

  // TODO(devtools): Handle errors.
  Future<ServiceExtensionResponse> close(
    String method,
    Map<String, String> parameters,
  ) async {
    await server.close(force: parameters['force'] == 'true');
    return ServiceExtensionResponse.result('{}');
  }

  registerExtension('ext.astra.reload', reload);
  registerExtension('ext.astra.close', close);
}
