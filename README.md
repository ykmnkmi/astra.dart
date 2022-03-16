A Shelf based web server framework and CLI tool.

_WORK IN PROGRESS_

```dart
// lib/[package].dart
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/serve.dart';

Response application(Request request) {
  switch (request.url.path) {
    case '':
      return Response.ok('counter: $counter!');
    case 'readme':
      return Response.ok(File('README.md').openRead());
    case 'error':
      throw Exception('some message');
    default:
      return Response.notFound('Request for "${request.url}"');
  }
}

Future<void> main() async {
  await serve(application, 'localhost', 3000);
  print('serving at http://localhost:3000');
}
```
(Not yet) Use `astra serve --reload`.
