import 'dart:developer' as developer show log;

import 'connection.dart';
import 'http.dart';
import 'types.dart';

Application log(Application application) {
  return (Connection connection) {
    var start = connection.start;
    var statusCode = StatusCodes.ok;

    connection.start =
        ({int status = StatusCodes.ok, String? reason, List<Header>? headers}) {
      statusCode = status;
      start(status: status, reason: reason, headers: headers);
    };

    try {
      return application(connection);
    } finally {
      developer.log('[$statusCode] ${connection.method} ${connection.url}');
    }
  };
}
