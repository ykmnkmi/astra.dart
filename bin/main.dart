import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:astra/serve.dart';

Response application(Request request) {
  throw Exception('hehe!');
}

Future<void> main() async {
  var handler = application.use(ServerErrorMiddleware(debug: true));
  var server = await serve(handler, 'localhost', 3000);
  print('serving at ${server.url}');
}
