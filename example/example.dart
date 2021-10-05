// ignore_for_file: avoid_print

import 'dart:async';

import 'package:astra/core.dart';
import 'package:logging/logging.dart';

FutureOr<void> application(Connection connection) {
  Response response;

  switch (connection.url.path) {
    case '/':
      response = TextResponse('hello world!');
      break;
    case '/error':
      throw AssertionError('some message');
    default:
      response = Response.notFound();
  }

  return response(connection);
}

void logger(String message, bool isError) {
  if (isError) {
    Logger.root.severe(message);
  } else {
    Logger.root.info(message);
  }
}

Future<void> main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(print);

  var server = await Server.bind('localhost', 3000);
  server.mount(log(error(application), logger: logger));
  print('serving at http://localhost:3000');
}
