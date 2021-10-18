import 'package:astra/core.dart';
import 'package:l/l.dart';

Future<void> application(Request request) {
  Response response;

  switch (request.url.path) {
    case '/':
      response = TextResponse('hello world!');
      break;
    case '/readme':
      response = FileResponse('README.md');
      break;
    case '/error':
      throw Exception('some message');
    default:
      response = Response.notFound();
  }

  return response(request);
}

void logger(String message, bool isError) {
  if (isError) {
    l << message;
  } else {
    l < message;
  }
}

Future<void> main() async {
  var server = await Server.bind('localhost', 3000);
  print('serving at ${server.url}');
  server.mount(error(log(application, logger: logger), debug: true));
}

// ignore_for_file: avoid_print