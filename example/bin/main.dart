import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await handler.serve('localhost', 3000);
  print('serving at ${server.url}');
}
