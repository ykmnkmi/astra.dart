import 'dart:async';

import 'package:shelf/shelf.dart';

/// Signature of base error handler.
typedef ErrorHandler = FutureOr<Response> Function(
    Request request, Object error, StackTrace stackTrace);
