// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';

import 'parser.dart';

Future<void> main() async {
  final header = 'GET /dart-lang/sdk/blob/master/sdk/lib/_http/http_impl.dart HTTP/1.1\r\n' 'Host: github.com\r\n\r\n';

  final parser = Parser();
  parser.listenToStream(Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(header))));

  await for (var icoming in parser) {
    print(icoming.method);
    print(icoming.uri);
    icoming.headers.raw.forEach(print);
  }
}
