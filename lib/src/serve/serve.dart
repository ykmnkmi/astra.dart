import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/utils.dart';

Future<Server> serve(Object application, Object host, int port,
    {SecurityContext? context, int backlog = 0, bool shared = false, bool v6Only = false}) async {
  var handler = await getHandler(application);
  InternetAddress address;

  if (host is String) {
    var addresses = await InternetAddress.lookup(host);
    assert(addresses.isNotEmpty);
    address = addresses.first;
  } else if (host is InternetAddress) {
    address = host;
  } else {
    // TODO: update error
    throw TypeError();
  }

  var server =
      IOServer(address, port, context: context, backlog: backlog, shared: shared, v6Only: v6Only);
  await server.start();
  server.mount(handler);
  return server;
}
