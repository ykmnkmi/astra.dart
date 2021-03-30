import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astra/astra.dart';
import 'package:astra/io.dart';

void app(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
  Request(scope, receive: receive).stream.transform<String>(utf8.decoder).listen(print);
  final response = TextResponse('Hello, world!\n');
  return response(scope, start, respond);
}

Future<void> main(List<String> arguments) async {
  final server = await start(ExceptionMiddleware(app), 'localhost', 3000);
  print('serving at http://localhost:3000');

  StreamSubscription<ProcessSignal>? subscription;
  subscription = ProcessSignal.sigint.watch().listen((signal) {
    print('');
    print('stoping server ...');
    subscription!.cancel();
    server.close(force: true);
  });
}
