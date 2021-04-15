import 'dart:async';

import 'package:astra/astra.dart';

FutureOr<void> application(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
  assert(scope['type'] == 'http');
  final response = TextResponse('Hello, world!\n');
  return response(scope, start, respond);
}
