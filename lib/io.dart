import 'dart:async' show FutureOr, StreamSubscription;
import 'dart:convert' show utf8;
import 'dart:io' show InternetAddressType, SecurityContext, ServerSocket, Socket, SocketOption;

import 'package:astra/astra.dart';

class IOServer implements Server {
  static Future<Server> bind(Object address, int port, {int backlog = 0, bool v6Only = false, bool shared = false, SecurityContext? context}) async {
    var socket = await ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
    return IOServer(socket, true);
  }

  IOServer(this.socketServer, this.closeServer) {
    // ...
  }

  IOServer.listenOn(this.socketServer) : closeServer = false;

  final ServerSocket socketServer;

  final bool closeServer;

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
        if (socket.address.type != InternetAddressType.unix) {
          socket.setOption(SocketOption.tcpNoDelay, true);
        }

        handleApplication(socket, application);
      });

      return;
    }

    subscription!.onData((Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }

      handleApplication(socket, application);
    });
  }

  Future<void> handleApplication(Socket socket, Application application) async {
    throw UnimplementedError();
  }
}
