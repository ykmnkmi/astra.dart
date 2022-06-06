library astra.core.error_handler;

import 'dart:async';

import 'package:astra/src/core/shelf.dart';

/// Signature of base error handler.
typedef ErrorHandler = FutureOr<Response> Function(Request request, Object error, StackTrace stackTrace);
