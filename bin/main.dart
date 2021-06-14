// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'parser.dart';

Future<void> main() async {
  final serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 3000);

  await for (var socket in serverSocket) {
    final parser = Parser();
    parser.listenToStream(socket);

    late StreamSubscription<Message> subscription;

    subscription = parser.listen((message) {
      if (message is HeadersMessage) {
        print(message.method);
        print(message.uri);
        message.headers.raw.forEach(print);
      }

      if (message.end) {
        print('> End');
        subscription.cancel();
      }
    });

    socket.write('HTTP/1.1 404 Not Found\r\n');
    socket.close();
  }
}
