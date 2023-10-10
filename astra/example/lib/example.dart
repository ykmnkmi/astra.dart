import 'dart:async';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';

Application get application {
  return Counter();
}

class Counter extends Application {
  int count = 0;

  @override
  Handler get entryPoint {
    return handler.use(logRequests()).use(error(debug: true));
  }

  Future<Response> handler(Request request) async {
    if (request.url.path == '') {
      return Response.ok('You have requested this route ${++count} time(s).');
    }

    if (request.url.path == 'isolate') {
      return Response.ok(Isolate.current.debugName);
    }

    if (request.url.path == 'throw') {
      throw Exception('Oh no!');
    }

    return Response.notFound('Not Found: ${request.url.path}');
  }

  @override
  Future<void> reload() async {
    count = 0;
    print('Application reloaded.');
  }

  @override
  Future<void> close() async {
    print('Application closed.');
  }
}
