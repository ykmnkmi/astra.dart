import 'dart:convert' show json;
import 'dart:developer' show ServiceExtensionResponse, registerExtension;

import 'package:astra/src/isolate/multi_isolate_server.dart';
import 'package:astra/src/serve/server.dart';

/// Registers useful extensions for the CLI and Dart DevTools.
void registerExtensions(Server server) {
  Future<ServiceExtensionResponse> reload(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      if (server is MultiIsolateServer) {
        await server.reload();
      } else if (server is ApplicationServer) {
        await server.reload();
      }

      return ServiceExtensionResponse.result('{}');
    } catch (error) {
      return ServiceExtensionResponse.result(json.encode({'error': '$error'}));
    }
  }

  Future<ServiceExtensionResponse> close(
    String method,
    Map<String, String> parameters,
  ) async {
    try {
      await server.close(force: parameters['force'] == 'true');
      return ServiceExtensionResponse.result('{}');
    } catch (error) {
      return ServiceExtensionResponse.result(json.encode({'error': '$error'}));
    }
  }

  registerExtension('ext.astra.reload', reload);
  registerExtension('ext.astra.close', close);
}
