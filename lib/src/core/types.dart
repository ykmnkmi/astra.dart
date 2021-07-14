import 'dart:async' show FutureOr;

import 'http.dart';
import 'request.dart';
import 'response.dart';

typedef Start = void Function({int status, String? reason, List<Header>? headers});

typedef Send = FutureOr<void> Function({List<int> bytes, bool flush, bool end});

typedef Application = FutureOr<void> Function(Request request, Start start, Send send);

typedef Handler = FutureOr<Response> Function(Request request);

typedef ExceptionHandler = FutureOr<Response> Function(Request request, Object error, StackTrace stackTrace);

typedef Middleware = Handler Function(Handler handler);
