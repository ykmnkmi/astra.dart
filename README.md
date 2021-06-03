# A simple web server framework based on starlette.

## WIP.

```dart
// lib/[package].dart

import 'dart:async';

import 'package:astra/astra.dart';

FutureOr<void> application(Map<String, Object?> scope, Receive receive, Start start, Send send) {
  final response = TextResponse('Hello, world!\n');
  return response(scope, start, respond);
}
```

(Not yet) And run `astra serve` or `astra build` for AOT compilation.

TODO: