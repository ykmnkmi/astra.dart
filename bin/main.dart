import 'dart:io';

void main() {
  void onServer(HttpServer server) {
    void onRequest(HttpRequest request) {
      print(request.uri);

      request.response
        ..headers.add('X-Message', '1')
        ..headers.set('X-Message', '2')
        ..headers.add('X-Message', '3')
        ..headers.contentLength = 0
        ..close();
    }

    server.listen(onRequest);
  }

  HttpServer.bind(InternetAddress.loopbackIPv4, 3000).then<void>(onServer);
}
