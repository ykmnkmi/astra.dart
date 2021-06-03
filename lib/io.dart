import 'dart:async' show StreamIterator;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, SecurityContext;

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

Future<void> handle(HttpRequest ioRequest, Application application) async {
  final response = ioRequest.response;

  void start({int status = StatusCodes.ok, String? reason, List<Header>? headers, bool buffer = false}) {
    response.statusCode = status;
    response.reasonPhrase = reason ?? ReasonPhrases.from(status);

    if (headers != null) {
      for (final header in headers) {
        response.headers.set(header.name, header.value);
      }
    }

    response.bufferOutput = buffer;
  }

  Future<void> send({List<int> bytes = const <int>[], bool end = false}) async {
    response.add(bytes);

    if (end) {
      if (response.bufferOutput) {
        await response.flush();
      }

      return response.close();
    }
  }

  await application(IORequest(ioRequest), start, send);
  response.close();
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
  Future<DataMessage> receive() async {
    if (await iterable.moveNext()) {
      return DataMessage(iterable.current);
    }

    return DataMessage.empty(end: true);
  }
}
