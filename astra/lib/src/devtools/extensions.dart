import 'dart:async' show Future;
import 'dart:convert' show json;
import 'dart:developer' show ServiceExtensionResponse, registerExtension;

import 'package:astra/src/serve/server.dart';

ServiceExtensionResponse _okResponse() {
  return ServiceExtensionResponse.result('{}');
}

ServiceExtensionResponse _errorResponse(Object error, StackTrace stackTrace) {
  return ServiceExtensionResponse.error(
    ServiceExtensionResponse.extensionError,
    json.encode(<String, Object?>{
      'error': '$error',
      'stackTrace': '$stackTrace',
    }),
  );
}

Future<void> registerExtensions(Server server) async {
  Future<ServiceExtensionResponse> close(
    String isolateId,
    Map<String, String> params,
  ) async {
    try {
      await server.close(force: params['force'] == 'true');
      return _okResponse();
    } catch (error, trace) {
      return _errorResponse(error, trace);
    }
  }

  registerExtension('ext.astra.close', close);
}
