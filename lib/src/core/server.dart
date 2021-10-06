import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io' show SecureServerSocket, SecurityContext, ServerSocket, Socket;

import 'parser.dart';
import 'request.dart';
import 'types.dart';

abstract class Server extends Stream<Request> {
  Uri get url;

  Future<void> close({bool force = false});

  void mount(Application application);

  void handle(Handler handler);

  static Future<Server> bind(Object address, int port,
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false,
      SecurityContext? context}) {
    return context == null
        ? ServerImpl.bind(address, port,
            backlog: backlog, v6Only: v6Only, shared: shared)
        : SecureServerImpl.bind(address, port, context,
            v6Only: v6Only, backlog: backlog, shared: shared);
  }
}

abstract class ServerBase extends Server {
  ServerBase() : controller = StreamController<Request>(sync: true);

  final StreamController<Request> controller;

  StreamSubscription<Request>? subscription;

  Stream<Socket> get server;

  Future<void> parseSocket(Socket socket) async {
    var request = await Parser.parse(this, socket);
    controller.add(request);
  }

  @override
  Future<void> close({bool force = false});

  @override
  StreamSubscription<Request> listen(void Function(Request event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    server.listen(parseSocket);
    return subscription = controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  void handle(Handler handler) {
    mount((request) async {
      var response = await handler(request);
      return response(request);
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
}

class ServerImpl extends ServerBase {
  static Future<ServerImpl> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    var serverSocket = await ServerSocket.bind(address, port,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return ServerImpl.listenOn(serverSocket);
  }

  ServerImpl.listenOn(this.server) : super();

  @override
  final ServerSocket server;

  @override
  Uri get url {
    var address = server.address;
    var host = address.isLoopback ? 'loopback' : address.host;
    return Uri(scheme: 'http', host: host, port: server.port);
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}

class SecureServerImpl extends ServerBase {
  static Future<SecureServerImpl> bind(
      Object address, int port, SecurityContext context,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    var serverSocket = await SecureServerSocket.bind(address, port, context,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return SecureServerImpl.listenOn(serverSocket);
  }

  SecureServerImpl.listenOn(this.server) : super();

  @override
  final SecureServerSocket server;

  @override
  Uri get url {
    var address = server.address;
    var host = address.isLoopback ? 'loopback' : address.host;
    return Uri(scheme: 'https', host: host, port: server.port);
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}
