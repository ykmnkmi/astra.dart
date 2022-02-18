A Shelf based web server framework.

_WORK IN PROGRESS_

```dart
// lib/[package].dart
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';
import 'package:l/l.dart';

Response echo(Request request) {
  switch (request.url.path) {
    case '':
      return Response.ok('hello world!');
    case 'readme':
      return Response.ok(File('README.md').openRead());
    case 'error':
      throw Exception('some message');
    default:
      return Response.ok('Request for "${request.url}"');
  }
}

void log(String message, bool isError) {
  if (isError) {
    l << message;
  } else {
    l < message;
  }
}

Future<void> main() async {
  var pipeline = Pipeline().addMiddleware(logger(log)).addMiddleware(error(debug: true));
  var handler = pipeline.addHandler(echo);
  var server = await serve(handler, 'localhost', 3000);
  print('serving at http://localhost:${server.port}');
}
```
(Not yet) Use `astra serve [[package|file:]application]`.
