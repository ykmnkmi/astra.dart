import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  var server = await application.serve('localhost', 3000);
  // ignore: avoid_print
  print('serving at ${server.url}');
}
