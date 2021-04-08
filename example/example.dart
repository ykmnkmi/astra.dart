import 'dart:async';
import 'dart:io';

import 'package:astra/astra.dart';
import 'package:astra/src/cli/io.dart';

FutureOr<void> application(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
  const names = <String>['jhon', 'jane'];
  final name = names[2];
  final response = TextResponse('Hello, $name!\n');
  return response(scope, start, respond);
}

Future<void> main(List<String> arguments) async {
  final server = await start(ServerErrorMiddleware(application, debug: true), 'localhost', 3000);
  print('serving at http://localhost:3000');

  StreamSubscription<ProcessSignal>? subscription;
  subscription = ProcessSignal.sigint.watch().listen((signal) {
    print('');
    print('stoping server ...');
    subscription!.cancel();
    server.close(force: true);
  });
}
