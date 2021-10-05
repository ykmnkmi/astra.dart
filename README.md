A simple web server framework (_work in progress_).

TODO: parsing and sending body properly

```dart
// lib/[package].dart

import 'dart:async';

import 'package:astra/astra.dart';

FutureOr<void> application(Request request, Start start, Send send) {
  Response response;

  if (connection.url.path == '/') {
    response = TextResponse('hello world!');
  } else {
    response = Response.notFound();
  }

  return response(connection);
}

Response handler(Request request) {
  return FileResponse('web/index.html');
}

Future<void> main() async {
  var server = await Server.bind('localhost', 3000);
  server.mount(log(error(application)));
  // server.handle(handler);
  print('serving at http://localhost:3000');
}
```

(Not yet) Use `astra serve [package]` or `astra build [package]` for AOT compilation.
