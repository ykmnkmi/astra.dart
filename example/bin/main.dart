import 'package:astra/serve.dart';
import 'package:example/example.dart';

Future<void> main() async {
  await application.serve('localhost', 3000);
  print('serving at http://localhost:3000');
}
