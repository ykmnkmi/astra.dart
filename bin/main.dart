import 'dart:io';

void main() {
  HttpServer.bind('localhost', 3000).then<void>((server) {
    server.listen((request) {
      var response = request.response;
      response
        ..statusCode = 404
        ..write('hello world!');

      response.flush().then<void>((void _) => response.close());
    });
  });
}
