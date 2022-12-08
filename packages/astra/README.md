[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is Shelf web server adapter and application framework.
Multi-isolate support and hot reload/restart. Inspired by [uvicorn][uvicorn].

**WORK IN PROGRESS, UNSTABLE**

### ToDo
- Verbose output 🔥
- More API Documentation 🔥
- Logging 🔥
- Tests 🔥
- Environment variables & configuration file
- Commands:
  - create
  - generate
  - build
  - ...
- ...

### Experimenting
- Shelf Request/Response based HttpServer alternatives:
  - dart:io Socket (without HttpRequest/HttpResponse, ...) 🤔
  - dart:ffi and Rust (hyper) web server adapter 🤔
  - ...
- HTTP/2 🤔
- Serving package URI (if possible) 🤔
- `build_runner` integration

## Quickstart

Install using `dart pub`:

```console
$ dart pub global activate astra
```

Create an application with `lib/[package].dart` file:

```dart
import 'dart:io';

import 'package:astra/core.dart';

Response application(Request request) {
  return Response.ok('hello world!');
}
```

Run the server:

```console
$ astra serve
```

## Usage

Run `serve` command to serve your application:

```console
$ astra serve -h
Serve application.

Usage: astra serve [arguments]
-h, --help                             Print this usage information.

Common options:
-d, --directory=<path>                 Run this in the directory.
-v, --verbose                          Output more informational messages.
    --version                          Prints tool version.

Application options:
-t, --target=<application>             Serve target.

Server options:
-s, --server-type=<shelf>              Server type.

          [h11]                        Default HTTP/1.1 adapter.

-j, --concurrency=<1>                  Number of isolates to run.
-a, --address=<localhost>              The address to listen.
-p, --port=<8080>                      The port to listen.
    --backlog=<0>                      Maximum number of connections to hold in backlog.
    --shared                           Socket connections distributing.
    --v6Only                           Restrict connections to version 6.
    --ssl-cert=<path>                  The path to a SSL certificate.
    --ssl-key=<path>                   The path to a private key.
    --ssl-key-password=<passphrase>    The password of private key file.

Debugging options:
-r, --reload                           Enable hot-reload and hot-restart.
-w, --watch                            Watch lib folder for changes and perform hot-reload.
-o, --observe=<8081>                   Enable VM observer.
-c, --asserts                          Enable asserts.

Run "astra help" to see global options.
```

### Running programmatically

To run server directly from your application:

`bin/main.dart`

```dart
import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 8080);
  print('Serving at ${server.url} ...');
}
```

[uvicorn]: https://github.com/encode/uvicorn