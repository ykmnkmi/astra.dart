[![Pub Package](https://img.shields.io/pub/v/astra.svg)](https://pub.dev/packages/astra)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Astra is an Shelf server application framework with CLI tool.

**WORK IN PROGRESS**

### TODO:
* Docs (I'm here)
* Verbose output (and there)
* Logger (help wanted)
* Manual hot reload & hot restart (help wanted)
* CLI Colors (help wanted)
* Replace HttpServer with Shelf Request/Response first server implementation. (experimenting here )

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

[path]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
