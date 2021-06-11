import 'package:http_parser/http_parser.dart' show parseHttpDate;

import 'http.dart';

Future<DataMessage> emptyReceive() async {
  return DataMessage.eos;
}

abstract class Connection {
  Headers get headers;

  Uri get url;

  Future<DataMessage> receive();
}

abstract class Request extends Connection {
  Request() : streamConsumed = false;

  bool streamConsumed;

  List<int>? receivedBody;

  String get method;

  Future<List<int>> get body async {
    if (receivedBody == null) {
      receivedBody = <int>[];

      await for (var bytes in stream) {
        receivedBody!.addAll(bytes);
      }
    }

    return receivedBody!;
  }

  DateTime? get ifModifiedSince {
    final date = headers.get(Headers.ifModifiedSince);

    if (date == null) {
      return null;
    } else {
      return parseHttpDate(date);
    }
  }

  Stream<List<int>> get stream async* {
    if (receivedBody != null) {
      yield receivedBody!;
    }

    if (streamConsumed) {
      throw StateError('Stream consumed');
    }

    var message = await receive();
    streamConsumed = true;

    while (!message.end) {
      yield message.bytes;
    }

    yield message.bytes;
  }
}
