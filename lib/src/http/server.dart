part of '../../http.dart';

abstract class NativeServer extends Server {
  NativeServer()
      : controller = StreamController<NativeRequest>(sync: true),
        active = LinkedList<Connection>(),
        idle = LinkedList<Connection>(),
        mounted = false,
        closed = false;

  @protected
  final StreamController<NativeRequest> controller;

  final LinkedList<Connection> active;

  final LinkedList<Connection> idle;

  @protected
  bool mounted;

  @protected
  bool closed;

  @protected
  Stream<Socket> get sockets;

  @protected
  Stream<NativeRequest> get requests {
    return controller.stream;
  }

  @protected
  void handleRequest(NativeRequest request) {
    if (closed) {
      request.connection.destroy();
    } else {
      controller.add(request);
    }
  }

  @protected
  void markIdle(Connection connection) {
    active.remove(connection);
    idle.add(connection);
  }

  @protected
  void markActive(Connection connection) {
    idle.remove(connection);
    active.add(connection);
  }

  @override
  Future<void> mount(Application application, [Logger? logger]) async {
    if (mounted) {
      throw StateError('Can\'t mount two handlers for the same server.');
    }

    mounted = true;

    await application.prepare();

    var handler = application.entryPoint;

    void body() {
      handler.handleRequests(requests, logger);
    }

    void onBodyError(Object error, StackTrace stackTrace) {
      logger?.warning('Asynchronous error.', error, stackTrace);
    }

    catchTopLevelErrors(body, onBodyError);

    void onSocket(Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }

      var connection = Connection(this, socket);
      idle.add(connection);
    }

    void onError(Object error, [StackTrace? stackTrace]) {
      // Ignore HandshakeExceptions as they are bound to a single request,
      // and are not fatal for the server.
      if (error is HandshakeException) {
        return;
      }

      controller.addError(error, stackTrace);
    }

    sockets.listen(onSocket, onError: onError, onDone: controller.close);
  }

  @override
  Future<void> close({bool force = false}) async {
    closed = true;
    await controller.close();

    if (force) {
      for (var connection in active.toList()) {
        connection.destroy();
      }

      assert(active.isEmpty);
    }

    for (var connection in idle.toList()) {
      connection.destroy();
    }
  }

  static Future<NativeServer> bind(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false}) async {
    if (securityContext == null) {
      return SocketServer.bind(address, port, //
          backlog: backlog,
          v6Only: v6Only,
          shared: shared);
    }

    return SecureSocketServer.bind(address, port, securityContext, //
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared);
  }
}

class SocketServer extends NativeServer {
  SocketServer(this.serverSocket);

  final ServerSocket serverSocket;

  @override
  InternetAddress get address {
    return serverSocket.address;
  }

  @override
  int get port {
    return serverSocket.port;
  }

  @override
  Stream<Socket> get sockets {
    return serverSocket;
  }

  @override
  Future<void> close({bool force = false}) async {
    await serverSocket.close();
    return super.close(force: force);
  }

  static Future<SocketServer> bind(Object address, int port, //
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false}) async {
    var socket = await ServerSocket.bind(address, port, //
        backlog: backlog,
        v6Only: v6Only,
        shared: shared);
    return SocketServer(socket);
  }
}

class SecureSocketServer extends NativeServer {
  SecureSocketServer(this.serverSocket);

  final SecureServerSocket serverSocket;

  @override
  InternetAddress get address {
    return serverSocket.address;
  }

  @override
  int get port {
    return serverSocket.port;
  }

  @override
  Stream<SecureSocket> get sockets {
    return serverSocket;
  }

  @override
  Future<void> close({bool force = false}) async {
    await serverSocket.close();
    return super.close(force: force);
  }

  static Future<SecureSocketServer> bind(Object address, int port, SecurityContext? securityContext, //
      {int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false}) async {
    var socket = await SecureServerSocket.bind(address, port, securityContext, //
        backlog: backlog,
        v6Only: v6Only,
        requestClientCertificate: requestClientCertificate,
        shared: shared);
    return SecureSocketServer(socket);
  }
}

// No async/await here
extension on FutureOr<Response?> Function(Request) {
  StreamSubscription<NativeRequest> handleRequests(Stream<NativeRequest> requests, [Logger? logger]) {
    void onRequest(NativeRequest request) {
      handleRequest(request, logger);
    }

    return requests.listen(onRequest);
  }

  // TODO: error response with message
  Future<void> handleRequest(NativeRequest request, [Logger? logger]) {
    var done = Completer<void>.sync();
    var response = Completer<Response?>();

    // TODO: abstract out hijack handling to make it easier to implement an adapter.
    Future<void> onResponse(Response? response) {
      if (response == null) {
        logger?.severe('Null response from handler.', '', StackTrace.current);
        response = Response.internalServerError();
        return request.respond(response);
      }

      if (request.canHijack) {
        return request.respond(response);
      }

      var message = StringBuffer('got a response for hijacked request ')
        ..write(request.method)
        ..write(' ')
        ..writeln(request.requestedUri)
        ..writeln(response.statusCode);

      void writeHeader(String key, String value) {
        message.writeln('$key: $value');
      }

      response.headers.forEach(writeHeader);

      throw Exception(message);
    }

    response.future.then<void>(onResponse).catchError(done.completeError);

    FutureOr<Response?> computation() {
      return this(request);
    }

    void onHijack(Object error, StackTrace stackTrace) {
      if (!request.canHijack) {
        done.complete();
        return;
      }

      logger?.severe('Caught HijackException, but the request wasn\'t hijacked.', error, stackTrace);
      response.complete(Response.internalServerError());
    }

    bool hijactTest(Object error) {
      return error is HijackException;
    }

    void onError(Object error, StackTrace stackTrace) {
      logger?.severe('Error thrown by handler.', error, stackTrace);
      response.complete(Response.internalServerError());
    }

    Future<Response?>.sync(computation)
        .then<void>(response.complete)
        .catchError(onHijack, test: hijactTest)
        .catchError(onError);

    return done.future;
  }
}
