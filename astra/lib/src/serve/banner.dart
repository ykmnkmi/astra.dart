import 'dart:io' show stderr, stdout;

import 'package:logging/logging.dart' show Level, LogRecord, Logger;

Logger defaultLoggerFactory() {
  var logger = Logger.root;
  logger.level = Level.CONFIG;

  void onRecord(LogRecord record) {
    if (record.error != null) {
      stderr.writeln(record.error);

      if (record.stackTrace != null) {
        stderr.writeln(record.stackTrace);
      }
    } else {
      stdout.writeln(record.message);
    }
  }

  logger.onRecord.listen(onRecord);
  return logger;
}

void logBanner(Logger logger) {
  const banner = r'''
    ___         __
   /   |  _____/ /____________
  / /| | / ___/ __/ ___/ __  /
 / ___ |/__  / /_/ /  / /_/ /_
/_/  |_/____/\__/_/   \______/''';

  const version = '1.0.0-dev.159';
  logger.config('$banner \u{1B}[31mv$version\u{1B}[0m\n\n');
}

void logUrl(Logger logger, Uri url) {
  logger.config('Serving at \u{1B}[32m$url\u{1B}[0m ...\n');
}
