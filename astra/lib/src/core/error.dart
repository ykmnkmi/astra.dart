import 'dart:async' show FutureOr;

import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
import 'package:shelf/shelf.dart' show Handler;

export 'package:shelf/shelf.dart' show HijackException;

/// A function that handles an error thrown by a [Handler].
typedef ErrorHandler = FutureOr<Response> Function(
  Request request,
  Object error,
  StackTrace stackTrace,
);
