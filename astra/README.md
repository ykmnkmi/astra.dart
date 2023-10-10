[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is Shelf web server adapter and application framework.
Multi-isolate support and hot reload/restart.
Inspired by [uvicorn][uvicorn] and [starlette][starlette].

**WORK IN PROGRESS**

### ToDo
- More API Documentation 🔥
- Logging 🔥
- Tests 🔥
- ...

### Experimenting
- Shelf `Request`/`Response` based `HttpServer` alternatives:
  - `dart:io` `Socket` (without `HttpRequest`/`HttpResponse`, ...) 🤔
  - `dart:ffi` and Go/Rust web server adapter 🤔
  - ...
- HTTP/2 🤔
- ...

## Quickstart

Create an application in `lib/[package].dart` file

```dart
import 'dart:io';

import 'package:astra/core.dart';

Response application(Request request) {
  return Response.ok('hello world!');
}
```

and `bin/main.dart` file

```dart
import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 8080);
  print('Serving at ${server.url} ...');
}
```

to run application.

[uvicorn]: https://github.com/encode/uvicorn
[starlette]: https://github.com/encode/starlette