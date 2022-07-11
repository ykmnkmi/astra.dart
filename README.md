[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is a [Shelf][shelf] web server with multi-threaded support and hot reload/restart. Inspired by [uvicorn][uvicorn].

**WORK IN PROGRESS**

### ToDo
- Errors, error handling and verbose output 🔥
- More API Documentation 🔥
- Logging
- Environment variables
- Tests
- Commands:
  - create
  - generate
  - ...
- ...

### Experimenting
- Shelf Request/Response based HttpServer alternative:
  - dart:io Socket 🤔
  - ...
- HTTP/2
- Hot-Reload `build_runner` integration

## Quickstart

Install using `dart pub`:

```console
$ dart pub global activate astra
```

Create an application, in `lib/[package].dart`:

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

Application options:
-t, --target=<application>             Serve target.
-j, --concurrency=<1>                  Number of isolates to run.

Server options:
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
  print('serving at ${server.url} ...');
}
```

### Application target

The `--target` option allows loading the application with different name and different types, defaults to `application`.

`Handler` function:
```console
$ astra serve --target echo
```
```dart
Response echo(Request request) {
  return Response.ok('hello world!');
}
```

`Handler` factory:
```console
$ astra serve --target getHandler
```
```dart
FutureOr<Handler> getHandler() {
  // ...
}
```

`Application` instance:
```console
$ astra serve --target example
```
```dart
const Example example = Example();
```

`Application` class:
```console
$ astra serve --target Example
```
```dart
class Example extends Application {
  // ...
}
```

`Application` factory:
```console
$ astra serve --target getApplication
```
```dart
FutureOr<Application> getApplication() {
  // ...
}
```

Not yet:
- `Handler` like callable class, instance and factory
- package URI (if possible)

[shelf]: https://github.com/dart-lang/shelf
[uvicorn]: https://github.com/encode/uvicorn
[path]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
