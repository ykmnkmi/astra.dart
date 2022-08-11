part of '../../http.dart';

abstract class ConnectionState {
  static const int active = 0;

  static const int idle = 1;

  static const int closing = 2;

  static const int detached = 3;
}

class Connection extends LinkedListEntry<Connection> {
  Connection(this.socket, this.server)
      : parser = Parser(),
        state = ConnectionState.idle,
        idle = false {
    parser.listenToStream(socket);

    void onIncoming(Incoming incoming) {
      server.markActive(this);

      // If the incoming was closed, close the connection.

      void onDataDone(bool closing) {
        if (closing) {
          destroy();
        }
      }

      incoming.dataDone.then<void>(onDataDone);

      // Only handle one incoming request at the time. Keep the
      // stream paused until the request has been send.
      subscription!.pause();
      state = ConnectionState.active;

      var outgoing = Outgoing(socket);
      var request = NativeRequest(server, incoming, this);

      void onDone(Socket socket) {
        if (state == ConnectionState.detached) {
          return;
        }

        if (request.persistentConnection && incoming.fullBodyRead && !parser.upgrade && !server.closed) {
          state = ConnectionState.idle;
          idle = false;
          server.markIdle(this);
          // Resume the subscription for incoming requests as the
          // request is now processed.
          subscription!.resume();
        } else {
          // Close socket, keep-alive not used or body sent before
          // received data was handled.
          destroy();
        }
      }

      void onError(Object error) {
        destroy();
      }

      streamFuture = outgoing.done.then<void>(onDone, onError: onError);
      outgoing.ignoreBody = request.method == 'HEAD';
      server.handleRequest(request);
    }

    // Ignore failed requests that was closed before headers was received.
    void onError(Object error) {
      destroy();
    }

    subscription = parser.listen(onIncoming, onDone: destroy, onError: onError);
  }

  final AstraServer server;

  final Socket socket;

  final Parser parser;

  int state;

  bool idle;

  StreamSubscription<void>? subscription;

  Future<void>? streamFuture;

  void destroy() {
    if (state == ConnectionState.closing || state == ConnectionState.detached) {
      return;
    }

    state = ConnectionState.closing;
    socket.destroy();
    unlink();
  }

  Future<Socket> detachSocket() async {
    state = ConnectionState.detached;
    unlink();

    var detachedIncoming = parser.detachIncoming();
    await streamFuture;
    return DetachedSocket(socket, detachedIncoming);
  }
}

class DetachedSocket extends Stream<Uint8List> implements Socket {
  DetachedSocket(this.socket, this.incoming);

  final Socket socket;

  final Stream<Uint8List> incoming;

  @override
  Encoding get encoding {
    return socket.encoding;
  }

  @override
  set encoding(Encoding value) {
    socket.encoding = value;
  }

  @override
  int get port {
    return socket.port;
  }

  @override
  InternetAddress get address {
    return socket.address;
  }

  @override
  InternetAddress get remoteAddress {
    return socket.remoteAddress;
  }

  @override
  int get remotePort {
    return socket.remotePort;
  }

  @override
  Future<void> get done {
    return socket.done;
  }

  @override
  bool setOption(SocketOption option, bool enabled) {
    return socket.setOption(option, enabled);
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    return socket.getRawOption(option);
  }

  @override
  void setRawOption(RawSocketOption option) {
    socket.setRawOption(option);
  }

  @override
  void add(List<int> bytes) {
    socket.add(bytes);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    socket.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return socket.addStream(stream);
  }

  @override
  void write(Object? obj) {
    socket.write(obj);
  }

  @override
  void writeln([Object? obj = '']) {
    socket.writeln(obj);
  }

  @override
  void writeCharCode(int charCode) {
    socket.writeCharCode(charCode);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    socket.writeAll(objects, separator);
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return incoming.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future<void> flush() {
    return socket.flush();
  }

  @override
  Future<void> close() {
    return socket.close();
  }

  @override
  void destroy() {
    socket.destroy();
  }
}
