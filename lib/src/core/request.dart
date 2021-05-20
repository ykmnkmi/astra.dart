import 'dart:async' show StreamController;

import 'package:http2/http2.dart' show DataStreamMessage;

import 'http.dart';

Future<DataStreamMessage> emptyReceive() {
  return Future<DataStreamMessage>.value(DataStreamMessage(const <int>[], endStream: true));
}

abstract class Request {
  Request() : streamConsumed = false;

  bool streamConsumed;

  List<int>? receivedBody;

  Headers get headers {
    throw UnimplementedError();
  }

  Future<List<int>> get body {
    if (receivedBody == null) {
      List<int> fold(List<int> chunks, List<int> chunk) {
        chunks.addAll(chunk);
        return chunks;
      }

      List<int> store(List<int> chunks) {
        receivedBody = chunks;
        return chunks;
      }

      return stream.fold<List<int>>(<int>[], fold).then<List<int>>(store);
    }

    return Future<List<int>>.value(receivedBody!);
  }

  Stream<List<int>> get stream {
    if (receivedBody != null) {
      return Stream<List<int>>.value(receivedBody!);
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
        receive().then<void>(get);
      } else {
        controller.close();
      }
    }

    receive().then<void>(get);
    return controller.stream;
  }

  Future<DataStreamMessage> receive();
}
