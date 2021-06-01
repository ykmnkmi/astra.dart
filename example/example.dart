import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/controllers.dart';
import 'package:astra/io.dart';

FutureOr<void> application(Request request, Start start, Respond respond) {
  final response = TextResponse(request.url.path);
  return response(request, start, respond);
}

Future<void> main() async {
  final server = await IOServer.bind('localhost', 3000);
  server(ExceptionMiddleware(ServerErrorMiddleware(application, debug: true)));
  print('serving at http://localhost:3000');
}
