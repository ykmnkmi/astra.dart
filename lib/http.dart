@experimental
library astra.http;

import 'dart:async';
import 'dart:collection' show HashMap, LinkedList, LinkedListEntry;
import 'dart:convert';
import 'dart:io'
    show
        HandshakeException,
        HttpDate,
        HttpException,
        HttpHeaders,
        InternetAddress,
        InternetAddressType,
        RawSocketOption,
        SecurityContext,
        ServerSocket,
        Socket,
        SocketOption;
import 'dart:typed_data';

import 'package:astra/core.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

part 'src/http/connection.dart';
part 'src/http/headers.dart';
part 'src/http/parser.dart';
part 'src/http/request.dart';
part 'src/http/response.dart';

// HTTP server waiting for socket connections.
class AstraServer extends Server {
  AstraServer.listenOn(ServerSocket serverSocket) : this(serverSocket, closeServer: false);

  AstraServer(this.serverSocket, {this.closeServer = true})
      : controller = StreamController<NativeRequest>(sync: true),
        active = LinkedList<Connection>(),
        idle = LinkedList<Connection>(),
        mounted = false,
        closed = false {
    controller.onCancel = close;

    void onTick(Timer timer) {
      for (var connection in idle.toList()) {
        if (connection.idle) {
          connection.destroy();
        } else {
          connection.idle = true;
        }
      }
    }

    timer = Timer.periodic(const Duration(seconds: 120), onTick);

    void onSocket(Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }

      // Accept the client connection.
      Connection connection = Connection(socket, this);
      idle.add(connection);
    }

    void onError(Object error, [StackTrace? stackTrace]) {
      // Ignore HandshakeExceptions as they are bound to a single request,
      // and are not fatal for the server.
      if (error is! HandshakeException) {
        controller.addError(error, stackTrace);
      }
    }

    serverSocket.listen(onSocket, onError: onError, onDone: controller.close);
  }

  final ServerSocket serverSocket;

  final bool closeServer;

  final StreamController<NativeRequest> controller;

  final LinkedList<Connection> active;

  final LinkedList<Connection> idle;

  @protected
  late Timer timer;

  @protected
  bool mounted;

  @protected
  bool closed;

  @override
  InternetAddress get address {
    return serverSocket.address;
  }

  @override
  int get port {
    return serverSocket.port;
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

  void handleRequest(NativeRequest request) {
    if (closed) {
      request.connection.destroy();
    } else {
      controller.add(request);
    }
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
      // TODO: serve request
      handler;
    }

    void onError(Object error, StackTrace stackTrace) {
      logger?.warning('Asynchronous error.', error, stackTrace);
    }

    catchTopLevelErrors(body, onError);
  }

  @override
  Future<void> close({bool force = false}) async {
    closed = true;

    if (closeServer) {
      await serverSocket.close();
    }

    timer.cancel();

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

  static Future<AstraServer> bind(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false}) async {
    var server = await ServerSocket.bind(address, port, //
        backlog: backlog,
        v6Only: v6Only,
        shared: shared);
    return AstraServer(server);
  }
}
