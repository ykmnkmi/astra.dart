import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/http.dart';

FutureOr<Response> hello(Request request) {
  return TextResponse('Hello, world!');
}

void main(List<String> arguments) {
  serve(hello);
}
