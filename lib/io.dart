/// Astra `dart:io` server implementation.
library astra.io;

import 'dart:async' show StreamIterator, StreamSubscription;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, SecurityContext;

import 'package:astra/core.dart';

class IOServer extends Server {
  static Future<Server> bind(Object address, int port,
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false,
      SecurityContext? context}) async {
    var server = await (context == null
        ? HttpServer.bind(address, port,
            backlog: backlog, v6Only: v6Only, shared: shared)
        : HttpServer.bindSecure(address, port, context,
            backlog: backlog, v6Only: v6Only, shared: shared));
    return IOServer.new(server);
  }

  IOServer(this.server);

  final HttpServer server;

  @override
  Future<void> close({bool force = false}) {
    return server.close(force: force);
  }

  StreamSubscription<IORequest>? subscription;

  @override
  void handle(Handler handler) {
    Future<void> application(Connection connection) async {
      var request = connection as Request;
      var response = await handler(request);
      return response(request);
    }

    if (subscription == null) {
      subscription = listen(application);
    } else {
      subscription!.onData(application);
    }
  }

  @override
  void mount(Application application) {
    if (subscription == null) {
      subscription = listen(application);
    } else {
      subscription!.onData(application);
    }
  }

  @override
  StreamSubscription<IORequest> listen(void Function(Connection event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    IORequest mapper(HttpRequest request) {
      void start(
          {int? status,
          String? reason,
          List<Header>? headers,
          bool buffer = false}) {
        var response = request.response;
        status ??= Codes.ok;

        response
          ..statusCode = status
          ..reasonPhrase = reason ?? ReasonPhrases.to(status);

        if (headers != null) {
          for (var header in headers) {
            response.headers.set(header.name, header.value);
          }
        }

        response.bufferOutput = buffer;
      }

      Future<void> send(
          {List<int>? bytes, bool flush = false, bool end = false}) async {
        var response = request.response;

        if (bytes != null) {
          response.add(bytes);
        }

        if (flush) {
          await response.flush();
        }

        if (end) {
          await response.close();
        }
      }

      return IORequest(request, start, send);
    }

    return subscription = server.map<IORequest>(mapper).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class IOHeaders implements Headers {
  IOHeaders(this.headers);

  final HttpHeaders headers;

  @override
  List<Header> get raw {
    var raw = <Header>[];

    headers.forEach((String name, List<String> values) {
      for (var value in values) {
        raw.add(Header(name, value));
      }
    });

    return raw;
  }

  @override
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
    return headers[name] ?? const <String>[];
  }

  @override
  MutableHeaders toMutable() {
    // UNDONE: update error
    throw UnimplementedError();
  }
}

class IOMutableHeaders extends IOHeaders implements MutableHeaders {
  IOMutableHeaders(HttpHeaders headers) : super(headers);

  @override
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
  IORequest(this.request, this.start, this.send)
      : headers = IOHeaders(request.headers);

  final HttpRequest request;

  @override
  final Headers headers;

  @override
  Start start;

  @override
  Send send;

  StreamIterator<List<int>>? iterator;

  @override
  String get version {
    return request.protocolVersion;
  }

  @override
  String get method {
    return request.method;
  }

  @override
  Uri get url {
    return request.uri;
  }

  @override
  Stream<List<int>> get stream {
    if (streamConsumed) {
      throw StateError('stream consumed');
    }

    streamConsumed = true;
    return request;
  }

  @override
  Future<DataMessage> receive() async {
    var iterator = this.iterator ??= StreamIterator<List<int>>(stream);
    var moveNext = await iterator.moveNext();
    return moveNext ? DataMessage(iterator.current) : DataMessage.eos;
  }
}
