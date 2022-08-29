Modified code copied from `dart:_http` and `shelf` package.

Current:
```dart
// simplified version
await for (Socket socket in SocketServer()) {
  // ...
  _HttpConnection connection = _HttpConnection(socket);
  // ...
  _HttpParser parser = _HttpParser(connection);

  // ...
  await for (HttpRequest httpRequest in parser) {
    // ...
    Request request = fromHttpRequest(httpRequest);
    Response response = await handler(request);
    // ...
    await writeResponse(response, httpRequest.httpResponse);
  }
}
```

...

Expected:
```dart
// simplified version
await for (Socket socket in SocketServer()) {
  // ...
  Connection connection = Connection(socket);

  // ...
  await for (Request request in connection) {
    Response response = await handler(request);
    // ...
    await request.respond(response);
  }
}
```
...
