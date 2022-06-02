library astra.serve.utils;

import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:stack_trace/stack_trace.dart';

// TODO: A developer mode is needed to include error info in response
// TODO: Make error output plugable. stderr, logging, etc
// TODO: document
void logError(Request request, String message, StackTrace stackTrace) {
  var buffer = StringBuffer('${request.method} ${request.requestedUri.path}');

  if (request.requestedUri.query.isNotEmpty) {
    buffer.write('?${request.requestedUri.query}');
  }

  buffer
    ..writeln()
    ..write(message);

  logTopLevelError(buffer.toString(), stackTrace);
}

// TODO: document
void logTopLevelError(String message, StackTrace stackTrace) {
  var frames = Chain.forTrace(stackTrace)
      .foldFrames((frame) => frame.isCore || frame.package == 'shelf' || frame.package == 'astra');

  stderr
    ..writeln('Error: ${DateTime.now()}')
    ..writeln(message)
    ..writeln(frames.terse);
}

/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If [this] is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
void catchTopLevelErrors(void Function() callback, void Function(Object error, StackTrace) onError) {
  if (Zone.current.inSameErrorZone(Zone.root)) {
    runZonedGuarded<void>(callback, onError);
  } else {
    callback();
  }
}
