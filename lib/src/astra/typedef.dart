part of '../../astra.dart';

typedef Receive = Future<DataMessage> Function();

typedef Start = Future<void> Function(int status, List<Header> headers);

typedef Respond = Future<void> Function(List<int> body);

typedef Handler = FutureOr<Response> Function(Request request);

typedef Application = Future<void> Function(Receive receive, Start start, Respond respond);
