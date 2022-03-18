[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is an Shelf server application framework with CLI tool.

**WORK IN PROGRESS**

## TODO:
* Docs (I'm here)
* Logger (help wanted)
* Manual hot reload & hot restart (help wanted)
* Colors (help wanted)
* Replace HttpServer with Shelf Request/Response first server implementation.

## Install

Use the dart pub global command to install this into your system.

```console
$ dart pub global activate astra
```

## Use

If you have [modified your PATH][path], you can run this from any local directory.

```console
$ astra serve
```

Otherwise you can use the `dart pub global` command.

```console
$ dart pub global run astra serve
```

## Example

```dart
// lib/[package].dart
import 'dart:io';

import 'package:astra/core.dart';

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

// bin/main.dart
import 'package:astra/serve.dart';
import 'package:[package]/[package].dart';

Future<void> main() async {
  await serve(application, 'localhost', 3000);
  print('serving at http://localhost:3000');
}
```

Use `astra serve -r -j 2`.

[path]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
