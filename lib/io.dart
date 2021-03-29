import 'dart:async' show StreamIterator;
import 'dart:convert' show ascii;
import 'dart:io' show HttpRequest, HttpServer, SecurityContext;

import 'astra.dart';

class IORunner implements Runner<HttpServer> {
  IORunner(this.server);

  @override
  final HttpServer server;

  @override
  Future<void> close({bool force = false}) {
    return server.close(force: force);
  }
}

Future<Runner<HttpServer>> start(Middleware application, Object? address, int port, {int backlog = 0, bool shared = false, SecurityContext? context}) {
  final serverFuture = context != null
      ? HttpServer.bindSecure(address, port, context, backlog: backlog, shared: shared)
      : HttpServer.bind(address, port, backlog: backlog, shared: shared);
  return serverFuture.then<Runner<HttpServer>>((HttpServer server) {
    serve(server, application);
    return IORunner(server);
  });
}

void serve(Stream<HttpRequest> server, Middleware application) {
  server.listen((HttpRequest request) {
    handle(request, application);
  });
}

void handle(HttpRequest request, Middleware application) {
  final response = request.response;

  final iterable = StreamIterator<List<int>>(request);

  Future<DataStreamMessage> receive() {
    return iterable.moveNext().then((hasNext) => hasNext ? DataStreamMessage(iterable.current) : DataStreamMessage(const <int>[], endStream: true));
  }

  void start(int status, List<Header> headers) {
    response.statusCode = status;

    for (final header in headers) {
      response.headers.set(ascii.decode(header.name), ascii.decode(header.value), preserveHeaderCase: true);
    }
  }

  void send(List<int> bytes) {
    response.add(bytes);
  }

  Future<void>.sync(() => application(receive, start, send)).then<void>((_) {
    response.close();
  });
}
