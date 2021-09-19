import 'dart:async' show StreamController, StreamSubscription;
import 'dart:collection' show LinkedList, LinkedListEntry;
import 'dart:io' show InternetAddressType, HandshakeException, ServerSocket, Socket, SocketOption;

import 'package:shelf/shelf.dart';

void main() {}

typedef VoidCallback = void Function();

class Connection extends LinkedListEntry<Connection> {
  Connection(this.socket, this.server);

  final Socket socket;

  final Server server;
}

class Server {
  static Future<Server> bind(Object address, int port, int backlog, bool v6Only, bool shared) async {
    final socket = await ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
    return Server.listenOn(socket);
  }

  Server.listenOn(this.serverSocket)
      : controller = StreamController<Request>(sync: true),
        connections = LinkedList<Connection>();

  final ServerSocket serverSocket;

  final StreamController<Request> controller;

  final LinkedList<Connection> connections;

  StreamSubscription<Request> listen(void Function(Request)? onData,
      {Function? onError, VoidCallback? onDone, bool? cancelOnError}) {
    void listener(Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }

      connections.add(Connection(socket, this));
    }

    void errorHandler(Object error, StackTrace stackTrace) {
      if (error is! HandshakeException) {
        controller.addError(error, stackTrace);
      }
    }

    serverSocket.listen(listener, onError: errorHandler, onDone: controller.close);
    return controller.stream.listen(onData, onError: errorHandler, onDone: onDone, cancelOnError: cancelOnError);
  }
}
