import 'dart:async';

import 'package:astra/core.dart';

FutureOr<Handler> getHandler(Object? object) {
  if (object is FutureOr<Handler>) {
    return object;
  }

  if (object is FutureOr<Handler> Function()) {
    return object();
  }

  throw ArgumentError.value(object);
}
