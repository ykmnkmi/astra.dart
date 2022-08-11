part of '../../http.dart';

abstract class NativeRequest implements Request {
  Connection get connection;

  bool get persistentConnection;
}
