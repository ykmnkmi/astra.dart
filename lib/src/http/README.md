Modified code copied from `dart:_http`.

From `Socket -> HttpServer -> HttpParser -> HttpRequest -> Requets`
To `Socket -> Server -> Parser -> Request`

Current call order:
...

New call order:
...

ToDo:
- `_HttpHeaders implements HttpHeaders` -> `NativeHeaders implements Map<String, List<String>>`
  - ...
- `_HttpRequest implements HttpRequest` -> `NativeRequest implements Request`
  - `NativeRequest.respond(Response response)`
  - ...
- `_HttpServer implements HttpServer` -> `NativeServer implements Server`
  - ...
