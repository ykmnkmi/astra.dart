import 'dart:async';

import 'package:astra/core.dart';

FutureOr<Handler> getHandler(Object? object) async {
  if (object is Handler) {
    return object;
  }

  if (object is FutureOr<Handler> Function()) {
    return object();
  }

  if (object is Application) {
    return object.call;
  }

  if (object is FutureOr<Application> Function()) {
    var application = await object();
    return application.call;
  }

  throw ArgumentError.value(object);
}
