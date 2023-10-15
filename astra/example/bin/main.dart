import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 8080);
  print('serving at ${server.url}');
}
