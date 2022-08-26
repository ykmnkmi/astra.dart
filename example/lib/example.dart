import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

// astra serve --t handler
Future<Response> handler(Request request) async {
  switch (request.url.path) {
    case '':
      return Response.ok('hello world!');
    case 'readme':
      return Response.ok(File('README.md').openRead());
    case 'error':
      throw Exception('some message');
    default:
      return Response.notFound('Request for "${request.url}"');
  }
}

// astra serve --t Router
class Router {
  Future<Response> call(Request request) {
    return handler(request);
  }
}

// astra serve --t router
final router = Router();

// astra serve --t getRouter
final getRouter = Router.new;

// astra serve --t App
class App extends Application {
  const App();

  @override
  Handler get entryPoint {
    return handler;
  }
}

// astra serve --t app
const app = App();

// astra serve --t getApp
Future<Application> getApp() async {
  return app;
}
