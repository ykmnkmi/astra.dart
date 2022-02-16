import 'dart:async';

import 'package:shelf/shelf.dart' show Request, Response;

export 'package:shelf/shelf.dart' show Request, Response;

typedef Handler = FutureOr<Response?> Function(Request request);

typedef ExceptionHandler = FutureOr<Response?> Function(
    Request request, Object error, StackTrace stackTrace);
