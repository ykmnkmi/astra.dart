library astra.io;

import 'dart:async' show StreamIterator;
import 'dart:convert' show ascii;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, SecurityContext;

import 'package:astra/astra.dart';

class IOServer implements Server<HttpServer> {
  static Future<Server<HttpServer>> bind(Object address, int port,
      {int backlog = 0, bool shared = false, SecurityContext? context}) {
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

  void start(int status, List<Header> headers) {
    response.statusCode = status;

    for (final header in headers) {
      response.headers.set(ascii.decode(header.name), ascii.decode(header.value));
    }
  }

  void send(List<int> bytes) {
    response.add(bytes);
  }

  dynamic request;
  Future<void>.sync(() => application(request, start, send)).then<void>((void _) => response.close());
}

class IOHeaders implements Headers {
  IOHeaders(this.headers);

  final HttpHeaders headers;

  @override
  List<Header> get raw {
    final raw = <Header>[];

    headers.forEach((String name, List<String> values) {
      for (final value in values) {
        raw.add(Header.ascii(name, value));
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
