import 'package:astra/core.dart';
import 'package:astra/serve.dart';

Response application(Request request) {
  throw Exception('application');
}

Future<void> main() async {
  var server = await serve(application, 'localhost', 3000);
  print('serving at ${server.url}');
}
