import 'dart:async' show FutureOr, StreamIterator;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, HttpStatus, SecurityContext;

import 'package:astra/astra.dart';

class IOServer implements Server<HttpServer> {
  static Future<Server<HttpServer>> bind(
    Object address,
    int port, {
    int backlog = 0,
    bool shared = false,
    SecurityContext? context,
  }) {
    final serverFuture = context != null
        ? HttpServer.bindSecure(address, port, context, backlog: backlog, shared: shared)
        : HttpServer.bind(address, port, backlog: backlog, shared: shared);
    return serverFuture.then<Server<HttpServer>>((HttpServer server) => IOServer(server));
  }

  IOServer(this.server);

  final HttpServer server;

  @override
  Future<void> close({bool force = false}) {
    return server.close(force: force);
  }

  @override
  void mount(Application application) {
    server.listen((HttpRequest request) {
      handle(request, application);
    });
  }
}

void handle(HttpRequest ioRequest, Application application) {
  final response = ioRequest.response;

  void start({int status = HttpStatus.ok, List<Header> headers = const <Header>[], bool buffer = false}) {
    response.statusCode = status;

    for (final header in headers) {
      response.headers.set(header.name, header.value);
    }

    response.bufferOutput = buffer;
  }

  FutureOr<void> send({List<int> bytes = const <int>[], bool end = false}) {
    response.add(bytes);

    if (end) {
      if (response.bufferOutput) {
        return response.flush().then<void>((_) => response.close());
      }

      return response.close();
    }
  }

  Future<void>.sync(() => application(IORequest(ioRequest), start, send)).then<void>((_) => response.close());
}

class IOHeaders implements Headers {
  IOHeaders(this.headers);

  final HttpHeaders headers;

  @override
  List<Header> get raw {
    final raw = <Header>[];

    headers.forEach((String name, List<String> values) {
      for (final value in values) {
        raw.add(Header(name, value));
      }
    });

    return raw;
  }

  @override
  bool contains(String name) {
    return headers[name] != null;
  }

  @override
  String? get(String name) {
    return headers.value(name);
  }

  @override
  List<String> getAll(String name) {
    return headers[name] ?? <String>[];
  }

  @override
  MutableHeaders toMutable() {
    throw UnimplementedError();
  }
}

class IOMutableHeaders extends IOHeaders implements MutableHeaders {
  IOMutableHeaders(HttpHeaders headers) : super(headers);

  @override
  void add(String name, String value) {
    headers.add(name, value);
  }

  @override
  void clear() {
    headers.clear();
  }

  @override
  void delete(String name) {
    headers.removeAll(name);
  }

  @override
  void set(String name, String value) {
    headers.set(name, value);
  }
}

class IORequest extends Request {
  IORequest(this.request)
      : iterable = StreamIterator<List<int>>(request),
        headers = IOHeaders(request.headers);

  final HttpRequest request;

  final StreamIterator<List<int>> iterable;

  @override
  final Headers headers;

  @override
  String get method {
    return request.method;
  }

  @override
  Uri get url {
    return request.uri;
  }

  @override
  Future<DataMessage> receive() {
    return iterable
        .moveNext()
        .then<DataMessage>((bool hasNext) => hasNext ? DataMessage(iterable.current) : DataMessage.empty(end: true));
  }
}
