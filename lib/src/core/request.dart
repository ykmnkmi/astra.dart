import 'dart:async' show StreamController;

import 'http.dart';

Future<DataMessage> emptyReceive() {
  return Future<DataMessage>.value(DataMessage.eos);
}

abstract class Request {
  Request() : streamConsumed = false;

  bool streamConsumed;

  List<int>? receivedBody;

  String get method;

  Future<List<int>> get body {
    if (receivedBody == null) {
      List<int> fold(List<int> body, List<int> chunk) {
        body.addAll(chunk);
        return body;
      }

      List<int> store(List<int> body) {
        receivedBody = body;
        return body;
      }

      return stream.fold<List<int>>(<int>[], fold).then<List<int>>(store);
    }

    return Future<List<int>>.value(receivedBody!);
  }

  Headers get headers;

  Stream<List<int>> get stream {
    if (receivedBody != null) {
      return Stream<List<int>>.value(receivedBody!);
    }

    if (streamConsumed) {
      return Stream<List<int>>.error(StateError('Stream consumed'));
    }

    streamConsumed = true;

    final controller = StreamController<List<int>>();

    void get(DataMessage message) {
      if (message.bytes.isNotEmpty) {
        controller.add(message.bytes);
      }

      if (!message.end) {
        receive().then<void>(get);
      } else {
        controller.close();
      }
    }

    receive().then<void>(get);
    return controller.stream;
  }

  Uri get url;

  Future<DataMessage> receive();
}
