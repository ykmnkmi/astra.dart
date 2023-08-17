import 'dart:async';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';

Application get application {
  return Counter();
}

class Counter extends Application {
  int count = 0;

  @override
  Handler get entryPoint {
    Future<Response> handler(Request request) async {
      return Response.ok('You have requested this application ${++count} time(s).');
    }

    return handler.use(logRequests());
  }

  @override
  Future<void> reload() async {
    print('Application reloaded.');
    count = 0;
  }

  @override
  Future<void> close() async {
    print('Application closed.');
  }
}
