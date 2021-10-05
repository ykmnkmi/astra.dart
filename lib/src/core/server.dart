import 'dart:async' show Completer, StreamController, StreamSubscription;
import 'dart:io'
    show
        IOSink,
        InternetAddressType,
        SecureServerSocket,
        SecurityContext,
        ServerSocket,
        Socket,
        SocketOption;

import 'connection.dart';
import 'http.dart';
import 'request.dart';
import 'types.dart';

part 'parser.dart';

abstract class Server extends Stream<Connection> {
  void mount(Application application);

  void handle(Handler handler);

  Future<void> close({bool force = false});

  static Future<Server> bind(Object address, int port,
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false,
      SecurityContext? context}) {
    return context == null
        ? _$Server.bind(address, port,
            backlog: backlog, v6Only: v6Only, shared: shared)
        : _$SecureServer.bind(address, port, context,
            v6Only: v6Only, backlog: backlog, shared: shared);
  }
}

class _Connection extends Connection {
  _Connection(this.stream, this.sink) : headers = MutableHeaders() {
    start = ({int? status, String? reason, List<Header>? headers}) {
      status ??= Codes.ok;
      sink.writeln(
          'HTTP/$version $status ${reason ?? ReasonPhrases.to(status)}');

      if (headers != null) {
        for (var header in headers) {
          sink.writeln('$header');
        }
      }

      sink.writeln();
    };

    send = ({List<int>? bytes, bool flush = false, bool end = false}) async {
      if (bytes != null) {
        sink.add(bytes);
      }

      if (flush) {
        await sink.flush();
      }

      if (end) {
        await sink.close();
      }
    };
  }

  @override
  final Stream<List<int>> stream;

  final IOSink sink;

  @override
  final MutableHeaders headers;

  @override
  late String version;

  @override
  late String method;

  @override
  late Uri url;

  @override
  late Start start;

  @override
  late Send send;

  @override
  Future<DataMessage> receive() {
    throw UnimplementedError();
  }
}

abstract class _Server extends Server {
  _Server() : controller = StreamController<Connection>(sync: true);

  final StreamController<Connection> controller;

  StreamSubscription<Connection>? subscription;

  Stream<Socket> get server;

  Future<void> parseSocket(Socket socket) async {
    var connection = await _Parser.parse(socket);
    controller.add(connection);
  }

  @override
  StreamSubscription<Connection> listen(void Function(Connection event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    server.listen(parseSocket);
    return subscription = controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  void handle(Handler handler) {
    mount((connection) async {
      var request = connection as Request;
      var response = await handler(request);
      return response(connection);
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
  Future<void> close({bool force = false});
}

class _$Server extends _Server {
  static Future<_Server> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    var server = await ServerSocket.bind(address, port,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return _$Server.listenOn(server);
  }

  _$Server.listenOn(this.server) : super();

  @override
  final ServerSocket server;

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}

class _$SecureServer extends _Server {
  static Future<_Server> bind(Object address, int port, SecurityContext context,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    var server = await SecureServerSocket.bind(address, port, context,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return _$SecureServer.listenOn(server);
  }

  _$SecureServer.listenOn(this.server) : super();

  @override
  final SecureServerSocket server;

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}
