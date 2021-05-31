import 'dart:async' show FutureOr;

import 'http.dart';
import 'request.dart';
import 'response.dart';

typedef Start = void Function(int status, [List<Header> headers]);

typedef Respond = void Function(List<int> body);

typedef Handler = FutureOr<Response> Function(Request request);

typedef ExceptionHandler = FutureOr<Response> Function(
    Request request, Object exception, StackTrace stackTrace);

typedef Application = FutureOr<void> Function(
    Request request, Start start, Respond respond);

abstract class Controller {
  FutureOr<void> call(Request request, Start start, Respond respond);

  FutureOr<Response> handle(Request request);
}
