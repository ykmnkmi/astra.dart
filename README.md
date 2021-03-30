# A simple web server framework.

Write some code.

```dart
// lib/package.dart

import 'dart:async';

import 'package:astra/astra.dart';

FutureOr<void> application(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
  final response = TextResponse('Hello, world!\n');
  return response(scope, start, respond);
}
```

And run `astra serve` or `astra build` for AOT compilation.
