import 'dart:convert';

import 'package:astra/core.dart';

// TODO: document this
Middleware debug() {
  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } on HijackException {
        rethrow;
      } catch (error) {
        var body = htmlEscape.convert(error.toString());
        var accept = request.headers['accept'];
        Map<String, String>? headers;

        if (accept != null && accept.contains('text/html')) {
          headers = <String, String>{'Content-Type': 'text/html'};
          body = '<html><body><h1>500 Server Error</h1><pre>$body</pre></body></html>';
        }

        return Response.internalServerError(body: body, headers: headers);
      }
    };
  };
}
