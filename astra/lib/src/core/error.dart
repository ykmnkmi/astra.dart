import 'dart:async' show FutureOr;

import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
export 'package:shelf/shelf.dart' show HijackException;

/// Signature of error handler.
typedef ErrorHandler = FutureOr<Response> Function(
  Request request,
  Object error,
  StackTrace stackTrace,
);
