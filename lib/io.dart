import 'dart:async' show StreamSubscription;
import 'dart:io' show InternetAddressType, SecurityContext, ServerSocket, Socket, SocketOption;

import 'package:astra/astra.dart';

class IOConnection implements Connection {
  IOConnection(this.socket, this.headers, this.url);

  final Socket socket;

  @override
  Headers headers;

  @override
  Uri url;

  @override
  Future<DataMessage> receive() {
    throw UnimplementedError();
  }
}

class IOServer implements Server {
  static const int active = 0;

  static const int idle = 1;

  static const int closing = 2;

  static const int detached = 3;

  IOServer(this.socketServer, this.closeServer) : connections = <IOConnection>[] {
    // ...
  }

  IOServer.listenOn(this.socketServer)
      : closeServer = false,
        connections = <IOConnection>[];

  final ServerSocket socketServer;

  final bool closeServer;

  final List<IOConnection> connections;

  StreamSubscription<Socket>? subscription;

  @override
  Future<void> close({bool force = false}) {
    throw UnimplementedError();
  }

  @override
  void handle(Handler handler) {
    throw UnimplementedError();
  }

  @override
  void mount(Application application) {
    if (subscription == null) {
      subscription = socketServer.listen((Socket socket) {
        handleApplication(socket, application);
      });

      return;
    }

    subscription!.onData((Socket socket) {
      handleApplication(socket, application);
    });
  }

  Future<void> handleApplication(Socket socket, Application application) async {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    throw UnimplementedError();
  }

  static Future<Server> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false, SecurityContext? context}) async {
    var socket = await ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
    return IOServer(socket, true);
  }
}
