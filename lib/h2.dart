import 'dart:async' show Completer, FutureOr;
import 'dart:collection' show Queue;
import 'dart:io' show SecurityContext, SecureServerSocket, SecureSocket;

import 'package:http2/transport.dart' show ServerTransportConnection, ServerTransportStream, StreamMessage;
import 'package:stack_trace/stack_trace.dart' show Trace;

import 'astra.dart';

Future<SecureServerSocket> serve(Application application, Object? address, int port, SecurityContext context) {
  return SecureServerSocket.bind(address, port, context).then<SecureServerSocket>((SecureServerSocket server) {
    server.listen(
      (SecureSocket socket) {
        final connection = ServerTransportConnection.viaSocket(socket);
        serveConnection(connection, application);
      },
    );

    return server;
  });
}

void serveConnection(ServerTransportConnection connection, Application application) {
  connection.incomingStreams.listen((ServerTransportStream stream) {
    final headers = Headers();
    final datas = Queue<DataStreamMessage>();

    FutureOr<DataStreamMessage> receive() {
      if (datas.isEmpty) {
        return DataStreamMessage(const <int>[], endStream: true);
      }

      return datas.removeFirst();
    }

    void start(int status, List<Header> headers) {
      stream.sendHeaders([Header.ascii(':status', '$status'), ...headers]);
    }

    void send(List<int> bytes) {
      stream.sendData(bytes);
    }

    final completer = Completer<void>();

    completer.future.then((_) {
      Future<void>.sync(() => application(receive, start, send)).then<void>((_) {
        stream.outgoingMessages.close();
      });
    });

    void complete() {
      if (completer.isCompleted) return;

      completer.complete();
    }

    stream.incomingMessages.listen((StreamMessage message) {
      if (message is HeadersStreamMessage) {
        for (final h2header in message.headers) {
          headers.raw.add(h2header);
        }
      } else if (message is DataStreamMessage) {
        complete();
        datas.addLast(message);
      }
    });
  }, onError: (Object error, StackTrace trace) {
    print(error);
    print(Trace.format(trace));
  });
}
