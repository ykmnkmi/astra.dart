part of '../../http.dart';

class NativeRequest implements Request {
  NativeRequest(this.server, this.connection, this.incoming);

  final NativeServer server;

  final Connection connection;

  final Incoming incoming;

  Future<void> respond(Response response) {
    throw UnimplementedError();
  }
}
