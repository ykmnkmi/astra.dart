import 'package:logging/logging.dart' show Logger;

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
