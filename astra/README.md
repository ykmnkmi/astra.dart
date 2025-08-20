[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A ~~robust~~, multi-threaded web server adapter designed for
~~high performance~~ and concurrent handling of multiple requests.

Inspired by [aqueduct][aqueduct], [uvicorn][uvicorn] and [starlette][starlette].

**WORK IN PROGRESS, API CAN CHANGE**

### ToDo
- Enhance API documentation 🔥
- Logging 🔥
- Write more tests 🔥
- ...

### Experimenting
- Exploring `Request`/`Response` based `HttpServer` alternatives 🤔
- Adding `HTTP/2` support
- ...

## Quickstart

Create an application in the `lib/[package].dart` file:

```dart
import 'dart:io';

import 'package:astra/core.dart';

Response application(Request request) {
  return Response.ok('hello world!');
}
```

and the `bin/main.dart` file:

```dart
import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 8080);
  print('Serving at ${server.url} ...');
}
```

to run application.

[aqueduct]: https://github.com/stablekernel/aqueduct
[shelf]: https://github.com/dart-lang/shelf
[starlette]: https://github.com/encode/starlette
[uvicorn]: https://github.com/encode/uvicorn