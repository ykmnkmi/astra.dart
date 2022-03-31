[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is a [Shelf][shelf] web server implementation with multi-threaded support and hot reload.

**WORK IN PROGRESS**

### ToDo:
- Errors, error handling and verbose output
- Application class based initialization
- Environment variables
- Tests
- More API Documentation
- Logging
- Manual hot reload (r) & hot restart (R)
- Middlewares:
  - ...
- ...
- Cookbook
- Replace HttpServer with Shelf Request/Response first server implementation (experimenting)

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
-t, --target=<name>                  Application handler or factory.
                                     (defaults to "application")
-j, --concurrency=<count>            Number of isolates.
                                     (defaults to "1")

Server options:
-a, --address=<internet-address>     Bind socket to this address.
                                     (defaults to "localhost")
-p, --port=<port>                    Bind socket to this port.
                                     (defaults to "3000")
    --backlog=<count>                Maximum number of connections to hold in backlog.
                                     (defaults to "0")
    --shared                         Socket connections distributing.
    --v6Only                         Restrict socket to version 6.
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

To run astra directly from your application:

`bin/main.dart`

```dart
import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  await serve(application, 'localhost', 3000);
  print('serving at http://localhost:3000');
}
```

### Application class

The `--target` option also allows loading the application from a factory
function, rather than a handler or an application instance directly.
The factory will be called with no arguments and should return a `Handler`,
`Application` or corresponding `Future`s.

```dart
class Hello extends Application {
  @override
  Response call(Request request) {
    return Response.ok('hello world!');
  }
}
```

```console
$ astra serve --target createApplication
```

[shelf]: https://pub.dev/packages/shelf
[path]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
