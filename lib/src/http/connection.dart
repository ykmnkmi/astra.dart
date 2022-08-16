part of '../../http.dart';

class Connection extends LinkedListEntry<Connection> {
  static const int active = 0;

  static const int idle = 1;

  static const int closing = 2;

  static const int detached = 3;

  Connection(this.server, this.socket)
      : parser = Parser(),
        state = idle,
        idleMark = false {
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
      state = active;

      var request = NativeRequest(server, this, incoming);
      server.handleRequest(request);
    }

    // Ignore failed requests that was closed before headers was received.
    void onError(Object error) {
      destroy();
    }

    subscription = parser.listen(onIncoming, onDone: destroy, onError: onError);
  }

  final NativeServer server;

  final Socket socket;

  final Parser parser;

  int state;

  StreamSubscription<void>? subscription;

  bool idleMark;

  Future<void>? streamFuture;

  void destroy() {
    if (state == closing || state == detached) {
      return;
    }

    state = closing;
    socket.destroy();
    unlink();
  }
}
