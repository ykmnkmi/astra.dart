import 'package:meta/meta.dart';

import 'headers.dart';
import 'message.dart';

typedef Receive = Future<DataMessage> Function();

Future<DataMessage> emptyReceive() {
  throw Exception();
}

Future<Message> emptyStart(int statusCode, List<Header> headers) {
  throw Exception();
}

Future<Message> emptyRespond(List<int> body) {
  throw Exception();
}

class Request {
  Request({this.receive = emptyReceive}) : streamConsumed = false;

  final Receive receive;

  @protected
  bool streamConsumed;

  @protected
  List<int>? consumedBody;

  Future<List<int>> get body async {
    if (consumedBody == null) {
      final body = <int>[];

      await for (final parts in stream) {
        body.addAll(parts);
      }

      consumedBody = body;
    }

    return consumedBody!;
  }

  String get method {
    throw UnimplementedError();
  }

  Stream<List<int>> get stream async* {
    if (consumedBody != null) {
      yield consumedBody!;
      return;
    }

    if (streamConsumed) {
      throw Exception();
    }

    streamConsumed = true;

    while (true) {
      final message = await receive();
      yield message.bytes;

      if (message.endStream) {
        break;
      }
    }
  }
}
