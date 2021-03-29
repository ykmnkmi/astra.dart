part of '../../astra.dart';

typedef Receive = FutureOr<DataStreamMessage> Function();

typedef Start = void Function(int status, List<Header> headers);

typedef Respond = void Function(List<int> body);

typedef Handler = FutureOr<Response> Function(Request request);

typedef Middleware = FutureOr<void> Function(Receive receive, Start start, Respond respond);

abstract class Application {
  FutureOr<void> call(Receive receive, Start start, Respond respond);
}
