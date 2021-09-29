import 'connection.dart';
import 'http.dart';

Future<DataMessage> emptyReceive() async {
  return DataMessage.eos;
}

abstract class Request extends Connection {
  Request() : streamConsumed = false;

  bool streamConsumed;

  List<int>? receivedBody;

  Future<List<int>> get body async {
    if (receivedBody == null) {
      receivedBody = <int>[];

      await for (var bytes in stream) {
        receivedBody!.addAll(bytes);
      }
    }

    return receivedBody!;
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
