[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is a [Shelf][shelf] web server implementation with multi-threaded support and hot reload.

**WORK IN PROGRESS**

### Progress status:
* Error handling and verbose output (I'm here)
* Tests (and there)
* API Documentation
* Logging
* Manual hot reload & hot restart
* Middlewares:
  * CORS
  * JWT
  * Trailing Slash
  * ...
* ...
* Replace HttpServer with Shelf Request/Response first server implementation (experimenting)
* Application framework on top of this

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

The astra command line tool is the easiest way to run your application...

### Command line options

```console
$ astra serve -h
Serve application.

Usage: astra serve [arguments]
-h, --help                           Print this usage information.

Common options:
-d, --directory=<path>               Run this in the directory.
-v, --verbose                        Output more informational messages.

Application options:
-t, --target=<name>                  The name of the handler or factory.
                                     (defaults to "application")

Server options:
-a, --host=<internet-address>        Socket bind host.
                                     (defaults to "localhost")
-p, --port=<port>                    Socket bind port.
                                     (defaults to "3000")
    --backlog=<count>                Socket listen backlog.
                                     (defaults to "0")
    --shared                         Socket connections distributing.
    --v6Only                         Restrict socket to version 6.
-j, --concurrency=<count>            The number of concurrent servers to serve.
                                     (defaults to "1")
    --ssl-cert=<path>                SSL certificate file.
    --ssl-key=<path>                 SSL key file.
    --ssl-key-password=<password>    SSL keyfile password.

Debugging options:
-r, --reload                         Enable hot-reload.
-o, --observe=<port>                 Enable VM Observer.
                                     (defaults to "3001")

Run "astra help" to see global options.
```

### Running programmatically

To run astra directly from your application...

`bin/main.dart`

```dart
import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  await serve(application, 'localhost', 3000);
  print('serving at http://localhost:3000');
}
```

### Application factories

The `--target` option also allows loading the application from a factory function,
rather than a handler or an application instance directly.
The factory will be called with no arguments and should return a `FutureOr<Handler>`.

```dart
class Hello extends Application {
  Hello(this.db);

  ...

  @override
  Response call(Request request) {
    return Response.ok('hello world!');
  }
}

Future<Handler> createApplication() async {
  var db = await loadDB();
  ...
  return logRequests().handle(Hello(db));
}
```

```console
$ astra serve --target createApplication
```

## Why Astra?

__WIP__

[shelf]: https://pub.dev/packages/shelf
[path]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
