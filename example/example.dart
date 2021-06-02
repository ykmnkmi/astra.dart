import 'dart:async';

import 'package:astra/astra.dart';
import 'package:astra/controllers.dart';
import 'package:astra/io.dart';

FutureOr<void> exmaple(Request request, Start start, Send send) {
  if (request.url.path != '/') {
    start(404);
    return null;
  }

  final response = TextResponse('hello');
  throw Exception('rieee!');
  return response(request, start, send);
}

Future<void> main() async {
  final server = await IOServer.bind('localhost', 3000);
  final application = ServerErrorMiddleware(exmaple);
  server.mount(application);
  print('serving at http://localhost:3000');
}
