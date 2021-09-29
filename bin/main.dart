import 'dart:async' show StreamSubscription;
import 'dart:convert' show Latin1Decoder;
import 'dart:io' show InternetAddressType, ServerSocket, Socket, SocketOption;

import 'package:astra/astra.dart';

import 'parser.dart';

Future<void> main() async {
  final server = await _Server.bind('localhost', 3000);

  await for (final connection in server) {
    print(connection);
  }
}

class _Connection extends Connection {
  static Future<_Connection> from(Socket socket) async {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    Parser(socket).listen((bytes) {
      print(bytes.length);
      print(bytes.take(10));
      print(const Latin1Decoder().convert(bytes));
    });

    Future<void>(() async {
      socket
        ..writeln('HTTP/1.1 404 Not Found')
        ..writeln();
      await socket.flush();
      await socket.close();
    });

    return _Connection(socket);
  }

  _Connection(this.socket);

  final Socket socket;

  @override
  late Send send;

  @override
  late Start start;

  @override
  String get method {
    throw UnimplementedError();
  }

  @override
  Uri get url {
    throw UnimplementedError();
  }

  @override
  Headers get headers {
    throw UnimplementedError();
  }

  @override
  Future<DataMessage> receive() {
    throw UnimplementedError();
  }
}

class _Server extends Server {
  static Future<_Server> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    final socket = await ServerSocket.bind(address, port,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return _Server.listenOn(socket);
  }

  _Server.listenOn(this.server);

  final ServerSocket server;

  StreamSubscription<Connection>? subscription;

  @override
  StreamSubscription<Connection> listen(void Function(Connection event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return subscription = server
        .asyncMap<Connection>(_Connection.from)
        .listen(onData, onError: onError, onDone: onDone);
  }

  @override
  void handle(Handler handler) {
    mount((connection) async {
      final request = connection as Request;
      final response = await handler(request);
      await response(connection);
    });
  }

  @override
  void mount(Application application) {
    final subscription = this.subscription;

    if (subscription == null) {
      listen(application);
    } else {
      subscription.onData(application);
    }
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}
