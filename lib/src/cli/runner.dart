import 'dart:async' show StreamSubscription;
import 'dart:io' show ProcessSignal, SecurityContext;

import 'package:astra/astra.dart';
import 'package:astra/io.dart';

void run(Application application, Object address, int port, {int backlog = 0, bool shared = false, SecurityContext? context, int isolates = 1}) {
  if (isolates == 1) {
    start(application, address, port, backlog: backlog, shared: shared, context: context).then((server) {
      StreamSubscription<ProcessSignal>? subscription;
      subscription = ProcessSignal.sigint.watch().listen((signal) {
        print('');
        print('stoping server ...');
        subscription!.cancel();
        server.close(force: true);
      });
    });
  } else {
    throw UnimplementedError();
  }
}
