import 'dart:io' show HttpStatus;

import 'connection.dart';
import 'http.dart';
import 'types.dart';

typedef LoggerCallback = void Function(String message, bool isError);

Application log(Application application, {required LoggerCallback logger}) {
  return (Connection connection) {
    var start = connection.start;
    var statusCode = HttpStatus.ok;

    connection.start =
        ({int status = HttpStatus.ok, String? reason, List<Header>? headers}) {
      statusCode = status;
      start(status: status, reason: reason, headers: headers);
    };

    var method = connection.method;
    var url = connection.url;

    Future<void>.value(application(connection)).then<void>((_) {
      var message = '$statusCode $method $url';
      logger(message, false);
    }).catchError((Object error, StackTrace trace) {
      logger('$statusCode $method $url\n$error\n$trace', true);
    });
  };
}
