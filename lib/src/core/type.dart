import 'dart:async' show FutureOr;

import 'package:http2/http2.dart' show DataStreamMessage, Header;

import 'request.dart';
import 'response.dart';

typedef Receive = FutureOr<DataStreamMessage> Function();

typedef Start = void Function(int status, List<Header> headers);

typedef Respond = void Function(List<int> body);

typedef Handler = FutureOr<Response> Function(Request request);

typedef Scope = Map<String, Object?>;

typedef ExceptionHandler = FutureOr<Response> Function(Request request, Object exception, StackTrace stackTrace);

typedef Application = FutureOr<void> Function(
    Map<String, Object?> scope, Receive receive, Start start, Respond respond);

abstract class ApplicationController {
  FutureOr<void> call(Map<String, Object?> scope, Receive receive, Start start, Respond respond);
}
