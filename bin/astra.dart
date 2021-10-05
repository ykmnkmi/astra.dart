import 'dart:convert' show utf8;

import 'package:astra/core.dart';

const List<Header> headers = <Header>[
  Header('content-length', '12'),
  Header('content-type', 'text/plain'),
];

void main() {
  Server.bind('localhost', 3000).then<void>((server) {
    print('listening at http://localhost:3000');

    server.listen((connection) {
      if (connection.url.path == '/') {
        connection
          ..start(status: Codes.ok, headers: headers)
          ..send(bytes: utf8.encode('hello world!'), flush: true, end: true);
        connection.headers.raw.forEach(print);
      } else {
        connection
          ..start(status: Codes.notFound)
          ..send(flush: true, end: true);
      }
    });
  });
}
