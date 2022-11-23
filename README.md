[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is a [Shelf][shelf] web server adapter with multi-threaded support and hot reload/restart.
Inspired by [uvicorn][uvicorn].

**WORK IN PROGRESS**

### ToDo
- Verbose output 🔥
- More API Documentation 🔥
- Logging 🔥
- Environment variables & configuration file
- Tests 🔥
- Commands:
  - create
  - generate
  - build
  - ...
- ...

### Experimenting
- Serving package URI (if possible) 🤔
- Shelf Request/Response based HttpServer alternatives:
  - dart:io Socket (without HttpRequest/HttpResponse, ...) 🤔
  - dart:ffi and Rust (hyper) web server adapter 🤔
  - ...
- HTTP/2 🔥
- `build_runner` integration

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
    --version                          Prints tool version.

Application options:
-t, --target=<application>             Serve target.

Server options:
-s, --server-type=<shelf>              Server type.

          [h11]                        Default HTTP/1.1 Shelf adapter.

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
  print('serving at ${server.url} ...');
}
```

### Application target

The `-t/--target` option allows loading the application with different names and different types, defaults to `application`.

`Application` class:
```console
$ astra serve -t HelloWorld
```
```dart
class HelloWorld extends Application {
  // ...
}
```

`Application` instance:
```console
$ astra serve -t example
```
```dart
FutureOr<Application> get example;
```

`Application` factory:
```console
$ astra serve -t getApplication
```
```dart
FutureOr<Application> getApplication();
```

`Handler` function:
```console
$ astra serve -t echo
```
```dart
FutureOr<Response> echo(Request request);
```

`Handler` like callable class:
```console
$ astra serve -t Router
```
```dart
class Router {
  FutureOr<Response> call(Request request);
}
```

`Handler` like callable class instance:
```console
$ astra serve -t router
```
```dart
FutureOr<Router> get router;
```

`Handler` factory:
```console
$ astra serve -t buildRouter
```
```dart
FutureOr<Handler> buildRouter();
```

[shelf]: https://github.com/dart-lang/shelf
[uvicorn]: https://github.com/encode/uvicorn
[path]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
