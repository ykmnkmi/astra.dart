import 'dart:async' show Completer, FutureOr;
import 'dart:collection' show Queue;
import 'dart:io' show HttpRequest, SecurityContext;

import 'package:astra/io.dart' show handle;
import 'package:http2/multiprotocol_server.dart' show MultiProtocolHttpServer;
import 'package:http2/transport.dart' show ServerTransportStream, StreamMessage;
import 'package:stack_trace/stack_trace.dart' show Trace;

import 'astra.dart';

Future<MultiProtocolHttpServer> serve(Application application, Object? address, int port, {SecurityContext? context}) {
  return MultiProtocolHttpServer.bind(address, port, context!).then<MultiProtocolHttpServer>((MultiProtocolHttpServer server) {
    server.startServing(
      (HttpRequest request) {
        handle(request, application);
      },
      (ServerTransportStream stream) {
        handleHttp2Request(stream, application);
      },
      onError: (Object? error, StackTrace stackTrace) {
        print(error);
        print(Trace.format(stackTrace));
      },
    );

    return server;
  });
}

void handleHttp2Request(ServerTransportStream stream, Application application) {
  final headers = Headers();
  final datas = Queue<DataStreamMessage>();

  FutureOr<DataStreamMessage> receive() {
    if (datas.isEmpty) {
      return DataStreamMessage(const <int>[], endStream: true);
    }

    return datas.removeFirst();
  }

  void start(int status, List<Header> headers) {
    stream.sendHeaders(<Header>[Header.ascii(':status', '$status'), ...headers]);
  }

  void send(List<int> bytes) {
    stream.sendData(bytes);
  }

  final completer = Completer<void>();

  completer.future.then((_) {
    Future<void>.sync(() => application(<String, Object?>{}, receive, start, send)).then<void>((_) {
      stream.outgoingMessages.close();
    });
  });

  stream.incomingMessages.listen((StreamMessage message) {
    if (message is HeadersStreamMessage) {
      for (final h2header in message.headers) {
        headers.raw.add(h2header);
      }
    } else if (message is DataStreamMessage) {
      if (!completer.isCompleted) {
        completer.complete();
      }

      datas.addLast(message);
    }
  });
}
