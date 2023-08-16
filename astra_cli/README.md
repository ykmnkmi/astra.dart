[![Pub Package](https://img.shields.io/pub/v/astra_cli.svg)][astra_cli]
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The [astra][] and [shelf][] command line tool. Inspired by [uvicorn][].

**WORK IN PROGRESS**

### ToDo
- Verbose output 🔥
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
- Serving package URI (if possible) 🤔
- `build_runner` integration

## Quickstart

Install using `dart pub`:

```console
$ dart pub global activate astra_cli
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
Serve Astra/Shelf application.

Usage: astra serve [options]
-h, --help                                Print this usage information.

Application options:
-t, --target=<application>                Application target.
    --target-path=<lib/[package].dart>    Application target location.
                                          Must be within application root folder.
-C, --directory=<.>                       Application root folder.
-D, --define=<key=value>                  Define an environment declaration.
-v, --verbose                             Print detailed logging.

Server options:
    --server-type=<h1x>                   Server type.

          [h1x]                           HTTP/1.x Shelf server.

-j, --concurrency=<1>                     Number of isolates.
-a, --address=<localhost>                 Bind server to this address.
                                          Bind will perform a InternetAddress.lookup and use the first value in the list.
-p, --port=<8080>                         Bind server to this port.
                                          If port has the value 0 an ephemeral port will be chosen by the system.
                                          The actual port used can be retrieved using the port getter.
    --backlog=<0>                         Number of connections to hold in backlog.
                                          If it has the value of 0 a reasonable value will be chosen by the system.
    --shared                              Specifies whether additional servers can bind to the same combination of address, port and v6Only.
                                          If it's true and more servers are bound to the port, then the incoming connections will be distributed among all the bound servers.
    --v6Only                              Restrict IP addresses to version 6 (IPv6) only.
                                          If an IP version 6 (IPv6) address is used, both IP version 6 (IPv6) and version 4 (IPv4) connections will be accepted.
    --ssl-key=<file.key>                  SSL key file.
    --ssl-cert=<file.crt>                 SSL certificate file.
    --ssl-key-password=<password>         SSL keyfile password.

Debugging options:
    --debug
    --hot
-w, --watch
    --service-port=<8181>
    --enable-asserts

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

[astra]: https://pub.dev/packages/astra
[astra_cli]: https://pub.dev/packages/astra_cli
[shelf]: https://pub.dev/packages/shelf
[uvicorn]: https://github.com/encode/uvicorn