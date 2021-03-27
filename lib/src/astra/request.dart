part of '../../astra.dart';

Future<DataMessage> emptyReceive() {
  throw UnimplementedError();
}

abstract class Request {
  Future<List<int>> get body;

  Headers get headers;

  Stream<List<int>> get stream;

  FutureOr<DataMessage> receive();
}
