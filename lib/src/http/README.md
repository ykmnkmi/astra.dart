A modified code copied from `dart:_http` and `shelf`.

Current implementation:

```dart
// simplified version
await for (Socket socket in SocketServer()) {
  // ...
  _HttpConnection connection = _HttpConnection(socket);

  // ...
  await for (HttpRequest httpRequest in connection) {
    // ...
    Request request = fromHttpRequest(httpRequest);
    Response response = await handler(request);
    // ...
    await writeResponse(response, httpRequest.httpResponse);
  }
}
```

...

Expected implementation:

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
