import 'package:astra/astra.dart';
import 'package:astra/io.dart';

void hello(Receive receive, Start start, Respond respond) {
  final response = TextResponse('Hello, world!');
  response(start, respond);
}

void main(List<String> arguments) {
  serve(hello, 'localhost', 3000).then<void>((server) {
    print('serving at http://localhost:3000');
  });
}
