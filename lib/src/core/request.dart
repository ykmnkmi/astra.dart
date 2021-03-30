import 'dart:async' show StreamController;

import 'package:http2/http2.dart' show DataStreamMessage;

import 'http.dart';
import 'types.dart';

Future<DataStreamMessage> emptyReceive() {
  throw UnimplementedError();
}

class Request {
  Request(this.receive) : streamConsumed = false;

  final Receive receive;

  bool streamConsumed;

  List<int>? cached;

  Future<List<int>> get body {
    if (cached == null) {
      return stream.fold<List<int>>(<int>[], (chunks, chunk) => chunks..addAll(chunk));
    }

    return Future<List<int>>.value(cached!);
  }

  Headers get headers {
    throw UnimplementedError();
  }

  Stream<List<int>> get stream {
    if (cached != null) {
      return Stream<List<int>>.value(cached!);
    }

    if (streamConsumed) {
      return Stream<List<int>>.error(StateError('Stream consumed'));
    }

    streamConsumed = true;

    final controller = StreamController<List<int>>();

    void get(DataStreamMessage message) {
      if (message.bytes.isNotEmpty) {
        controller.add(message.bytes);
      }

      if (!message.endStream) {
        Future<DataStreamMessage>.sync(() => receive()).then(get);
      } else {
        controller.close();
      }
    }

    Future<DataStreamMessage>.sync(() => receive()).then(get);
    return controller.stream;
  }
}
