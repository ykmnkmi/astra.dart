import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';

Application application() {
  return Counter();
}

final class Counter extends Application {
  int count = 0;

  @override
  Handler get entryPoint {
    return handler.use(logRequests()).use(error(debug: true));
  }

  Future<Response> handler(Request request) async {
    count += 1;

    messageHub?.add(1);

    if (request.url.path == '') {
      return Response.ok('You have requested this application $count time(s).');
    }

    if (request.url.path == 'isolate') {
      return Response.ok(Isolate.current.debugName);
    }

    if (request.url.path == 'send') {
      const headers = {'Content-Type': 'application/json; charset=utf-8'};

      var body = json.encode(request.url.queryParameters);
      return Response.ok(body, headers: headers);
    }

    if (request.url.path == 'throw') {
      throw Exception('Oh no!');
    }

    return Response.notFound('Not Found: ${request.url.path}');
  }

  void onMessage(Object? event) {
    if (event is int) {
      count += event;
    }
  }

  @override
  Future<void> prepare() async {
    messageHub?.listen(onMessage);
  }

  @override
  Future<void> reload() async {
    count = 0;
    print('Reset count.');
  }

  @override
  Future<void> close() async {
    print('Total count: $count.');
  }
}
