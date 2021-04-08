import 'dart:async' show StreamSubscription;
import 'dart:io' show ProcessSignal, SecurityContext;

import 'package:astra/astra.dart';

import 'io.dart';

abstract class Runner<T> {
  Future<void> close({bool force = false});
}

void run(Application application, Object address, int port,
    {int backlog = 0, bool shared = false, SecurityContext? context, int isolates = 1}) {
  if (isolates == 1) {
    start(application, address, port, backlog: backlog, shared: shared, context: context).then((server) {
      StreamSubscription<ProcessSignal>? subscription;
      subscription = ProcessSignal.sigint.watch().listen((signal) {
        print('\nstoping server ...');
        subscription!.cancel();
        server.close(force: true);
      });
    });
  } else {
    throw UnimplementedError();
  }
}
