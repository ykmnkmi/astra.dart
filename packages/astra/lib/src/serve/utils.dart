import 'dart:async' show Zone, runZoned, runZonedGuarded;
import 'dart:io' show stderr;

import 'package:stack_trace/stack_trace.dart' show Trace;

/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If [this] is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
void catchTopLevelErrors(
  void Function() callback,
  void Function(Object error, StackTrace) onError,
) {
  if (Zone.current.inSameErrorZone(Zone.root)) {
    runZonedGuarded<void>(callback, onError);
  } else {
    callback();
  }
}

/// Default function to log errors.
void logError(Object error, StackTrace stackTrace) {
  stderr
    ..write('ERROR - ')
    ..write(DateTime.now())
    ..write(' ')
    ..writeln(error)
    ..writeln(Trace.format(stackTrace));
}
