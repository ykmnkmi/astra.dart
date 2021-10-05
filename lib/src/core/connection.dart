import 'http.dart';
import 'types.dart';

abstract class Connection {
  String get version;

  String get method;

  Uri get url;

  Headers get headers;

  Stream<List<int>> get stream;

  abstract Start start;

  abstract Send send;

  Future<DataMessage> receive();

  @override
  String toString() {
    return 'Connection($method, $url, $version)';
  }
}
