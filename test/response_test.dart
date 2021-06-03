import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/testing.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> main() async {
  try {
    FutureOr<void> application(Request request, Start start, Send send) {
      final response = TextResponse('hello world!');
      return response(request, start, send);
    }

    final client = TestClient(application);
    final response = await client.get(Uri.parse('/'));
    print(response.body);
  } catch (e, st) {
    print(e);
    print(Trace.format(st));
  }
}
