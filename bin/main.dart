import 'dart:async' show StreamController, StreamSubscription;
import 'dart:convert' show utf8;
import 'dart:io' show InternetAddressType, ServerSocket, Socket, SocketOption;

import 'package:astra/astra.dart';

part 'parser.dart';

Future<void> main() async {
  var server = await ServerSocket.bind('localhost', 3000);
  server.listen((socket) async {});
}

class _Connection extends Connection {
  static Future<Connection> parse(Socket socket) async {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    var subscription = Parser(socket).listen(null);
    subscription.onData((bytes) {
      if (bytes.isEmpty) {
        subscription.pause();
        subscription.onData(print);
        subscription.resume();
        return;
      }

      print('>>> ${utf8.decode(bytes)}');
    });

    socket.writeln('HTTP/1.1 404 Not Found');
    await socket.flush();
    await socket.close();

    throw UnimplementedError();
  }

  _Connection(this.socket);

  final Socket socket;

  @override
  late String method;

  @override
  late Uri url;

  @override
  late Headers headers;

  @override
  late Send send;

  @override
  late Start start;

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
        .asyncMap<Connection>(_Connection.parse)
        .listen(onData, onError: onError, onDone: onDone);
  }

  @override
  void handle(Handler handler) {
    mount((connection) async {
      var request = connection as Request;
      var response = await handler(request);
      await response(connection);
    });
  }

  @override
  void mount(Application application) {
    var subscription = this.subscription;

    if (subscription == null) {
      this.subscription = listen(application);
    } else {
      subscription.onData(application);
    }
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}
