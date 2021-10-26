import 'http.dart';
import 'request.dart';
import 'response.dart';

typedef Start = void Function(int status, {List<Header>? headers, bool buffer});

typedef Send = void Function(List<int> bytes);

typedef Application = Future<void> Function(Request request);

typedef Handler = Future<Response> Function(Request request);

typedef ExceptionHandler = Future<Response> Function(Request connection, Object error, StackTrace stackTrace);

typedef Middleware = Handler Function(Handler handler);
