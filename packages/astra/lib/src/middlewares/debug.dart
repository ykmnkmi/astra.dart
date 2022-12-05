import 'dart:convert';

import 'package:astra/core.dart';

Middleware debug() {
  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } on HijackException {
        rethrow;
      } catch (error) {
        var body = htmlEscape.convert('$error');
        var accept = request.headers['accept'];
        Map<String, String>? headers;

        if (accept != null && accept.contains('text/html')) {
          headers = <String, String>{'Content-Type': 'text/html'};
          body = '<!DOCTYPE html>'
              '<html>'
              '<head>'
              '<meta charset="UTF-8">'
              '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
              '<title>Internal Server Error</title>'
              '</head>'
              '<body>$body</body>'
              '</html>';
        }

        return Response.internalServerError(body: body, headers: headers);
      }
    };
  };
}
