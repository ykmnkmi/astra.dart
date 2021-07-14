A simple web server framework based on starlette (_work in progress_).

```dart
// lib/[package].dart

import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/io.dart';

FutureOr<void> application(Request request, Start start, Send send) {
  final response = request.url.path == '/' ? TextResponse('hello world!') : Response.notFound();
  return response(request, start, send);
}

Response handler(Request request) {
  return request.url.path == '/' ? FileResponse('web/index.html') : Response.notFound();
}

Future<void> main() async {
  final server = await IOServer.bind('localhost', 3000);
  server.mount(log(error(application)));
  // server.handle(handler);
  print('serving at http://localhost:3000');
}
```

(Not yet) Use `astra serve [package]` or `astra build [package]` for AOT compilation.
