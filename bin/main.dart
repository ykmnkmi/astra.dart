import 'dart:convert';
import 'dart:io';

import 'parser.dart';

Future<void> main() async {
  final codec = const Utf8Encoder();

  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 8080);
  print(server.address);

  server.listen((socket) async {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    final message = await HttpParser.parseStream(socket);
    print(message.method);
    print(message.uri);
    message.headers?.forEach((key, value) {
      print('$key: $value');
    });
    print(message.fullBodyRead);

    if (message.uri?.path == '/') {
      socket.write('HTTP/1.1 200 Ok\r\n');
      socket.write('\r\n');
      socket.write('hello world!\r\n');
    } else {
      socket.write('HTTP/1.1 404 Not Found');
    }

    socket.close();
    print('');
  });
}
