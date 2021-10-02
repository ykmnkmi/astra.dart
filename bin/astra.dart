import 'dart:async' show StreamController, StreamSubscription;
import 'dart:convert' show utf8;
import 'dart:io' show InternetAddressType, RawSocket, ServerSocket, Socket, SocketOption;

import 'package:astra/astra.dart';

part 'parser.dart';

void main() {
  _Server.bind('localhost', 3000).then<void>((server) {
    server.listen((connection) {
      connection
        ..start(status: StatusCodes.notFound)
        ..send(bytes: utf8.encode('hello world!'), end: true);
    });
  });
}

class _Connection extends Connection {
  _Connection(this.socket) {
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

    start = ({int status = StatusCodes.ok, String? reason, List<Header>? headers}) {
      socket.writeln('HTTP/1.1 $status ${reason ?? ReasonPhrases.to(status)}');

      if (headers != null) {
        for (var header in headers) {
          socket.writeln('$header');
        }
      }

      socket.writeln();
    };

    send = ({List<int>? bytes, bool flush = false, bool end = false}) {
      if (bytes != null) {
        socket.add(bytes);
      }

      if (flush) {
        if (end) {
          return socket.flush().then<void>((void _) => socket.close());
        }

        return socket.flush();
      }

      socket.done;

      if (end) {
        return socket.close();
      }
    };
  }

  final Socket socket;

  @override
  late String method;

  @override
  late Uri url;

  @override
  late Headers headers;

  @override
  late Start start;

  @override
  late Send send;

  @override
  Future<List<int>> receive() {
    throw UnimplementedError();
  }

  @override
  String toString() {
    return '_Connection()';
  }
}

class _Server extends Server {
  static Future<_Server> bind(Object address, int port, {int backlog = 0, bool v6Only = false, bool shared = false}) {
    return ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared)
        .then<_Server>(_Server.listenOn);
  }

  _Server.listenOn(this.server);

  final ServerSocket server;

  StreamSubscription<Connection>? subscription;

  @override
  StreamSubscription<Connection> listen(void Function(Connection event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return subscription = server.map<Connection>(_Connection.new).listen(onData, onError: onError, onDone: onDone);
  }

  @override
  void handle(Handler handler) {
    mount((connection) {
      var request = connection as Request;
      return Future<Response>.value(handler(request)).then<void>((respone) => respone(connection));
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
