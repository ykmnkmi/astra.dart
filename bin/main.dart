import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:astra/serve.dart';

class Hello extends Application {
  Hello(this.name);

  final String name;

  int counter = 0;

  @override
  Future<Response> call(Request request) async {
    counter += 1;

    switch (request.url.path) {
      case '':
        return Response.ok('$name: $counter!');
      case 'readme':
        return Response.ok(File('README.md').openRead());
      case 'error':
        throw Exception('some message');
      default:
        return Response.notFound('Request for "${request.url}"');
    }
  }

  @override
  void reassemble() {
    counter = 0;
  }
}

Handler application(String name) {
  return logRequests().handle(Hello(name));
}

Future<void> startServer(String name) async {
  await serve(application(name), 'localhost', 3000, shared: true);
  print('$name: serving at http://localhost:3000');
}

Future<void> main() async {
  await startServer('isolate/0');

  for (var i = 1; i < Platform.numberOfProcessors; i += 1) {
    await Isolate.spawn(startServer, 'isolate/$i');
  }
}
