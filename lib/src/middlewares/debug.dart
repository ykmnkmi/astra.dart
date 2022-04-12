import 'dart:convert';

import 'package:astra/core.dart';

Middleware debug() {
  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (error) {
        var accept = request.headers['accept'];
        Map<String, String>? headers;

        if (accept != null && accept.contains('text/html')) {
          headers = <String, String>{'Content-Type': 'text/html'};
        }

        var errorString = htmlEscape.convert(error.toString());
        var body = '<html><body><h1>500 Server Error</h1><pre>$errorString</pre></body></html>';
        return Response.internalServerError(body: body, headers: headers);
      }
    };
  };
}
