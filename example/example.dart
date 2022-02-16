import 'package:astra/core.dart';
import 'package:l/l.dart';

Response handler(Request request) {
  switch (request.url.path) {
    case '/':
      return TextResponse.ok('hello world!');
    case '/readme':
      return FileResponse.ok('README.md');
    case '/error':
      throw Exception('some message');
    default:
      return Response.notFound(null);
  }
}

void logger(String message, bool isError) {
  if (isError) {
    l << message;
  } else {
    l < message;
  }
}

Future<void> main() async {
  var server = await serve(error(log(handler, logger: logger), debug: true), 'localhost', 3000);
  print('serving at http://localhost:${server.port}');
}

// ignore_for_file: avoid_print
