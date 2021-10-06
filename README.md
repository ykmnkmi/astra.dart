A simple web server framework (_work in progress_).

TODO: parsing and sending body properly

```dart
// lib/[package].dart

import 'dart:async';

import 'package:astra/core.dart';

Future<void> application(Request request, Start start, Send send) {
  Response response;

  if (connection.url.path == '/') {
    response = TextResponse('hello world!');
  } else {
    response = Response.notFound();
  }

  return response(connection);
}

Future<void> main() async {
  var server = await Server.bind('localhost', 3000);
  print('serving at ${server.url}');
  server.mount(log(error(application)));
}
```

(Not yet) Use `astra serve [package]` or `astra build [package]` for AOT compilation.
