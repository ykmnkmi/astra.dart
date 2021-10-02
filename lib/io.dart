/// Astra `dart:io` server implementation.
library astra.io;

import 'dart:async' show StreamIterator, StreamSubscription;
import 'dart:io' show HttpHeaders, HttpRequest, HttpServer, SecurityContext;

import 'package:astra/astra.dart';

class IOServer extends Server {
  static Future<Server> bind(Object address, int port,
      {int backlog = 0, bool shared = false, SecurityContext? context}) {
    var future = context == null
        ? HttpServer.bind(address, port, backlog: backlog, shared: shared)
        : HttpServer.bindSecure(address, port, context, backlog: backlog, shared: shared);
    return future.then<Server>(IOServer.new);
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
    Future<void> application(Connection connection) {
      var request = connection as Request;
      return Future<Response>.value(handler(request)).then<void>((response) => response(request));
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
    return subscription = server
        .map<IORequest>(IORequest.new)
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
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
    // TODO: update error
    throw UnsupportedError('');
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
  IORequest(this.request) : headers = IOHeaders(request.headers) {
    start = ({int status = StatusCodes.ok, String? reason, List<Header>? headers, bool buffer = false}) {
      var response = request.response;
      response
        ..statusCode = status
        ..reasonPhrase = reason ?? ReasonPhrases.to(status);

      if (headers != null) {
        for (var header in headers) {
          response.headers.set(header.name, header.value);
        }
      }

      response.bufferOutput = buffer;
    };

    send = ({List<int>? bytes, bool flush = false, bool end = false}) {
      var response = request.response;

      if (bytes != null) {
        response.add(bytes);
      }

      if (flush) {
        if (end) {
          return response.flush().then<void>((void _) => response.close());
        }

        return response.flush();
      }

      if (end) {
        return response.close();
      }
    };
  }

  final HttpRequest request;

  @override
  final Headers headers;

  @override
  late Start start;

  @override
  late Send send;

  StreamIterator<List<int>>? iterator;

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
      throw StateError('Stream consumed');
    }

    streamConsumed = true;
    return request;
  }

  @override
  Future<List<int>> receive() {
    var iterator = this.iterator ??= StreamIterator<List<int>>(stream);
    return iterator.moveNext().then<List<int>>((moved) => moved ? iterator.current : <int>[]);
  }
}
