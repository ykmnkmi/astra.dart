import 'dart:async' show StreamController;

import 'package:http2/http2.dart' show DataStreamMessage;

import 'http.dart';
import 'type.dart';

Future<DataStreamMessage> emptyReceive() {
  throw UnimplementedError();
}

class Request {
  Request(this.scope, {this.receive = emptyReceive}) : streamConsumed = false;

  final Map<String, Object?> scope;

  final Receive receive;

  bool streamConsumed;

  Headers? _headers;

  List<int>? _body;

  Headers get headers {
    return _headers ??= Headers(scope: scope);
  }

  Future<List<int>> get body {
    if (_body == null) {
      return stream.reduce((chunks, chunk) => chunks + chunk).then<List<int>>((chunks) => _body = chunks);
    }

    return Future<List<int>>.value(_body!);
  }

  Stream<List<int>> get stream {
    if (_body != null) {
      return Stream<List<int>>.value(_body!);
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
