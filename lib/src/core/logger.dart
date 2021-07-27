import 'http.dart';
import 'request.dart';
import 'types.dart';

Application log(Application application) {
  return (Request request, Start start, Send send) {
    var statusCode = StatusCodes.ok;

    void started({int status = StatusCodes.ok, String? reason, List<Header>? headers}) {
      statusCode = status;
      start(status: status, reason: reason, headers: headers);
    }

    try {
      return application(request, started, send);
    } finally {
      print('[$statusCode] ${request.method} ${request.url}');
    }
  };
}
