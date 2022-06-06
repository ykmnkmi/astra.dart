library astra.serve;

import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/h11.dart';

export 'package:astra/src/serve/h11.dart' show H11Server;
export 'package:astra/src/serve/utils.dart' show logError, logTopLevelError, catchTopLevelErrors;

// TODO: add options: concurency, debug, reload, http, ...
Future<Server> serve(Handler handler, Object address, int port,
    {SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false}) async {
  var server = await H11Server.bind(address, port,
      securityContext: securityContext,
      backlog: backlog,
      v6Only: v6Only,
      requestClientCertificate: requestClientCertificate,
      shared: shared);
  server.mount(handler);
  return server;
}
