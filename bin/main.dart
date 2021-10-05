import 'dart:io';

void main() {
  HttpServer.bind('localhost', 3000).then<void>((server) {
    server.listen((request) {
      var response = request.response;

      if (request.uri.path == '/') {
        response
          ..statusCode = 202
          ..write('hello world!');
      } else {
        response.statusCode = 404;
      }

      response.flush().then<void>((void _) => response.close());
    });
  });
}
