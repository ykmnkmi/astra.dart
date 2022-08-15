part of '../../http.dart';

class Incoming {
  Incoming(Headers headers, int transferLength, Stream<Uint8List> body) {
    throw UnimplementedError();
  }

  set upgraded(bool upgraded) {
    throw UnimplementedError();
  }

  set uri(Uri uri) {
    throw UnimplementedError();
  }

  set method(String method) {
    throw UnimplementedError();
  }

  void close(bool closing) {
    throw UnimplementedError();
  }
}
