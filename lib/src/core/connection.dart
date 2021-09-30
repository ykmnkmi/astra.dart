import 'http.dart';
import 'types.dart';

abstract class Connection {
  String get method;

  Uri get url;

  Headers get headers;

  abstract Start start;

  abstract Send send;

  Future<DataMessage> receive();

  @override
  String toString() {
    return 'Connection($method, $url)';
  }
}
