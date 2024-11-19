import 'dart:io' show stderr, stdout;
import 'package:logging/logging.dart' show Level, LogRecord, Logger;

/// Configures and return the root [Logger].
Logger defaultLoggerFactory() {
  return Logger.root
    ..level = Level.CONFIG
    ..onRecord.listen(_onRecord);
}

void _onRecord(LogRecord record) {
  if (record.error != null) {
    stderr.writeln(record.error);

    if (record.stackTrace != null) {
      stderr.writeln(record.stackTrace);
    }
  } else {
    stdout.writeln(record.message);
  }
}
