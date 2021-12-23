import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io'
    show
        InternetAddressType,
        SecureServerSocket,
        SecurityContext,
        ServerSocket,
        Socket,
        SocketOption;
import 'dart:typed_data';

import 'http.dart';
import 'parser.dart';
import 'request.dart';
import 'types.dart';

enum State {
  request,
  headers,
}

Future<Request> parse(Server server, Socket socket) async {
  if (socket.address.type != InternetAddressType.unix) {
    socket.setOption(SocketOption.tcpNoDelay, true);
  }

  var controller = StreamController<List<int>>(sync: true);
  var state = State.request;

  late String method;
  late String url;
  late String version;
  var headers = MutableHeaders();

  await for (var bytes in Parser(socket, controller.sink)) {
    if (bytes.isEmpty) {
      break;
    }

    // TODO: update errors
    switch (state) {
      case State.request:
        var start = 0, end = bytes.indexOf(32);

        if (end == -1) {
          throw Exception('method');
        }

        method = String.fromCharCodes(bytes.sublist(start, start = end));
        end = bytes.indexOf(32, start += 1);

        if (end == -1) {
          throw Exception('uri');
        }

        url = String.fromCharCodes(bytes.sublist(start, start = end));

        if (start + 9 != bytes.length ||
            bytes[start += 1] != 72 ||
            bytes[start += 1] != 84 ||
            bytes[start += 1] != 84 ||
            bytes[start += 1] != 80 ||
            bytes[start += 1] != 47 ||
            bytes[start += 1] != 49 ||
            bytes[start + 1] != 46) {
          throw Exception('version');
        }

        version = String.fromCharCodes(bytes.sublist(start));
        state = State.headers;
        break;

      case State.headers:
        var index = bytes.indexOf(58);

        if (index == -1) {
          throw Exception('header field');
        }

        var name = String.fromCharCodes(bytes.sublist(0, index));
        var value = String.fromCharCodes(bytes.sublist(index + 2));
        headers.add(name.toLowerCase(), value);
        break;

      default:
        throw UnimplementedError();
    }
  }

  // TODO: implement buffering
  void start(int status, {List<Header>? headers, bool buffer = true}) {
    var builder = BytesBuilder();
    // socket.writeln('HTTP/$version $status ${ReasonPhrases.to(status)}');
    builder
      ..add(const <int>[72, 84, 84, 80, 47])
      ..add(version.codeUnits)
      ..addByte(32)
      ..add(status.toString().codeUnits)
      ..addByte(32)
      ..add(ReasonPhrases.to(status).codeUnits)
      ..addByte(13)
      ..addByte(10);

    if (headers != null) {
      for (var header in headers) {
        builder
          ..add(header.name.codeUnits)
          ..addByte(58)
          ..addByte(32);

        var values = header.values;
        builder.add(values[0].codeUnits);

        for (var i = 1; i < values.length; i += 1) {
          builder
            ..addByte(44)
            ..addByte(32)
            ..add(values[i].codeUnits);
        }

        builder
          ..addByte(13)
          ..addByte(10);
      }
    }

    builder
      ..addByte(13)
      ..addByte(10);
    socket.add(builder.takeBytes());
  }

  void send(List<int> bytes) {
    socket.add(bytes);
  }

  Future<void> flush() {
    return socket.flush();
  }

  Future<void> close() {
    return socket.close();
  }

  return Request(controller.stream, socket, method, Uri.parse(url), version, headers, start, send,
      flush, close);
}

abstract class Server extends Stream<Request> {
  Uri get url;

  Future<void> close({bool force = false});

  void mount(Application application);

  void handle(Handler handler);

  static Future<Server> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false, SecurityContext? context}) {
    return context == null
        ? ServerImpl.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared)
        : SecureServerImpl.bind(address, port, context,
            v6Only: v6Only, backlog: backlog, shared: shared);
  }
}

abstract class ServerBase extends Server {
  ServerBase() : controller = StreamController<Request>(sync: true);

  final StreamController<Request> controller;

  StreamSubscription<Request>? subscription;

  Stream<Socket> get server;

  @override
  Future<void> close({bool force = false});

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

  Future<void> parseSocket(Socket socket) async {
    var request = await parse(this, socket);
    controller.add(request);
  }

  @override
  StreamSubscription<Request> listen(void Function(Request event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    server.listen(parseSocket);
    return subscription = controller.stream
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class ServerImpl extends ServerBase {
  static Future<ServerImpl> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    var server =
        await ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
    return ServerImpl.listenOn(server);
  }

  ServerImpl.listenOn(this.server) : super();

  @override
  final ServerSocket server;

  @override
  Uri get url {
    if (server.address.isLoopback) {
      return Uri(scheme: 'http', host: 'localhost', port: server.port);
    }

    if (server.address.type == InternetAddressType.IPv6) {
      return Uri(scheme: 'http', host: '[${server.address.address}]', port: server.port);
    }

    return Uri(scheme: 'http', host: server.address.address, port: server.port);
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}

class SecureServerImpl extends ServerBase {
  static Future<SecureServerImpl> bind(Object address, int port, SecurityContext context,
      {int backlog = 0, bool v6Only = false, bool shared = false}) async {
    var server = await SecureServerSocket.bind(address, port, context,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return SecureServerImpl.listenOn(server);
  }

  SecureServerImpl.listenOn(this.server) : super();

  @override
  final SecureServerSocket server;

  @override
  Uri get url {
    if (server.address.isLoopback) {
      return Uri(scheme: 'https', host: 'localhost', port: server.port);
    }

    if (server.address.type == InternetAddressType.IPv6) {
      return Uri(scheme: 'https', host: '[${server.address.address}]', port: server.port);
    }

    return Uri(scheme: 'https', host: server.address.address, port: server.port);
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close();
  }
}
