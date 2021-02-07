import 'headers.dart';

typedef Start = Future<void> Function(int statusCode, List<Header> headers);

typedef Respond = Future<void> Function(List<int> body);
