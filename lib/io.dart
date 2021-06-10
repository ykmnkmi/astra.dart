import 'dart:async' show StreamIterator, StreamSubscription;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, SecurityContext;

import 'package:astra/astra.dart';

class IOServer implements Server {
  static Future<Server> bind(Object address, int port,
      {int backlog = 0, bool shared = false, SecurityContext? context}) {
    final serverFuture = context != null
        ? HttpServer.bindSecure(address, port, context, backlog: backlog, shared: shared)
        : HttpServer.bind(address, port, backlog: backlog, shared: shared);
    return serverFuture.then<Server>((HttpServer server) => IOServer(server));
  }

  IOServer(this.server);

  final HttpServer server;

  @override
  Future<void> close({bool force = false}) {
    return server.close(force: force);
  }

  StreamSubscription<HttpRequest>? subscription;

  @override
  void handle(Handler handler) {}

  @override
  void mount(Application application) {
    if (subscription == null) {
      subscription = server.listen((HttpRequest ioRequest) {
        handleApplication(ioRequest, application);
      });

      return;
    }

    subscription!.onData((HttpRequest ioRequest) {
      handleApplication(ioRequest, application);
    });
  }
}

void handleApplication(HttpRequest ioRequest, Application application) {
  final ioResponse = ioRequest.response;

  void start({int status = StatusCodes.ok, String? reason, List<Header>? headers, bool buffer = false}) {
    ioResponse.statusCode = status;
    ioResponse.reasonPhrase = reason ?? ReasonPhrases.from(status);

    if (headers != null) {
      for (final header in headers) {
        ioResponse.headers.set(header.name, header.value);
      }
    }

    ioResponse.bufferOutput = buffer;
  }

  Future<void> send({List<int> bytes = const <int>[], bool flush = false, bool end = false}) async {
    ioResponse.add(bytes);

    if (flush) {
      await ioResponse.flush();
    }

    if (end) {
      await ioResponse.close();
    }
  }

  application(IORequest(ioRequest), start, send);
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
  @pragma('vm:prefer-inline')
  String? operator [](String name) {
    return get(name);
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
  @pragma('vm:prefer-inline')
  void operator []=(String name, String value) {
    set(name, value);
  }

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
