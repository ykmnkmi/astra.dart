// ignore_for_file: avoid_print

import 'package:astra/core.dart';

Stream<String> numbers(int minimum, int maximum) async* {
  yield '$minimum';
  minimum += 1;

  for (; minimum <= maximum; minimum += 1) {
    await Future<void>.delayed(Duration(milliseconds: 500));
    yield ', $minimum';
  }
}

Future<void> application(Request request) {
  Response response;

  switch (request.url.path) {
    case '/':
      response = TextResponse('hello world!');
      break;
    case '/stream':
      response = StreamResponse.text(numbers(5, 10), buffer: true);
      break;
    case '/file':
      response = FileResponse('README.md');
      break;
    case '/error':
      throw AssertionError('some message');
    default:
      response = Response.notFound();
  }

  return response(request);
}

void logger(String message, bool isError) {
  print(message);
}

Future<void> main() async {
  var server = await Server.bind('localhost', 3000);
  print('listening at ${server.url}');
  server.mount(error(log(application, logger: logger)));
}
