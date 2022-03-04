import 'dart:async';
import 'dart:developer';

import 'package:astra/src/core/application.dart';
import 'package:shelf/shelf.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

FutureOr<Handler> getHandler(Object? object) async {
  if (object is Handler) {
    return object;
  }

  if (object is FutureOr<Handler> Function()) {
    return object();
  }

  if (object is Application) {
    return object.call;
  }

  if (object is FutureOr<Application> Function()) {
    var application = await object();
    return application.call;
  }

  throw ArgumentError.value(object);
}

Future<VmService> getService({bool silence = true}) async {
  var info = await Service.controlWebServer(enable: true, silenceOutput: silence);
  var serverWebSocketUri = info.serverWebSocketUri;

  if (serverWebSocketUri == null) {
    throw Exception('service not running');
  }

  return vmServiceConnectUri(serverWebSocketUri.toString());
}
