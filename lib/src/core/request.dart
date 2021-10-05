import 'connection.dart';

abstract class Request extends Connection {
  Request() : streamConsumed = false;

  bool streamConsumed;

  List<int>? receivedBody;

  Future<List<int>> get body {
    var receivedBody = this.receivedBody;

    if (receivedBody == null) {
      return stream.fold<List<int>>(
          this.receivedBody = <int>[], (body, chunk) => body..addAll(chunk));
    }

    return Future<List<int>>.value(receivedBody);
  }
}
