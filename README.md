# A simple web server framework based on starlette.

## WIP.

```dart
// lib/[package].dart

import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/controllers.dart';
import 'package:astra/io.dart';

FutureOr<void> example(Request request, Start start, Send send) {
  var response = Response(status: 404);
  return response(request, start, send);
}

Future<void> main() async {
  var server = await IOServer.bind('localhost', 3000);
  var application = ServerErrorMiddleware(example, debug: true);
  server.mount(application);
  print('serving at http://localhost:3000');
}
```

(Not yet) and run `astra serve [[package]:first]` or `astra build [package]:second` for AOT compilation.
