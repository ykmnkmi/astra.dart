import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astra/src/core/http.dart' show MutableHeaders;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart' show protected;

const int lf = 10, cr = 13;

enum State {
  request,
  headers,
  body,
}

class Parser {
  Parser(this.socket)
      : subscription = socket.listen(null),
        request = PartialRequest(),
        state = State.request,
        carry = const <int>[],
        skipLeadingLF = false,
        newLinesCount = 0 {
    subscription
      ..pause()
      ..onData(onData)
      ..onDone(onDone)
      ..resume();
  }

  final Socket socket;

  final StreamSubscription<List<int>> subscription;

  final Completer<Request> completer = Completer<Request>.sync();

  final PartialRequest request;

  State state;

  List<int> carry;

  bool skipLeadingLF;

  int newLinesCount;

  Future<Request> get done {
    return completer.future;
  }

  void addLines(List<int> bytes, int start) {
    var sliceStart = start, end = bytes.length;
    var char = 0;

    for (var i = start; i < end; i += 1) {
      var previousChar = char;
      char = bytes[i];

      if (char != cr) {
        if (char != lf) {
          newLinesCount = 0;
          continue;
        }

        if (previousChar == cr) {
          newLinesCount += 1;

          if (newLinesCount == 2) {
            carry = bytes.sublist(sliceStart + 1);
            serve();
            return;
          }

          sliceStart = i + 1;
          continue;
        }
      }

      parse(bytes.sublist(sliceStart, i));
      sliceStart = i + 1;
    }

    if (sliceStart < end) {
      carry = bytes.sublist(sliceStart, end);
    } else {
      skipLeadingLF = char == cr;
    }
  }

  void onData(List<int> bytes) {
    var start = 0;

    if (carry.isNotEmpty) {
      if (skipLeadingLF) {
        throw StateError('skipLeadingLF must not be true');
      }

      bytes = carry + bytes.sublist(start);
      carry = const <int>[];
    } else if (skipLeadingLF) {
      if (bytes[start] == lf) {
        start += 1;
      }

      skipLeadingLF = false;
    }

    addLines(bytes, start);
  }

  void onDone() {
    if (completer.isCompleted) {
      return;
    }

    if (state == State.body) {
      serve();
    }

    throw StateError('request not parsed');
  }

  void parse(List<int> bytes) {
    switch (state) {
      case State.request:
        var start = 0, end = bytes.indexOf(32);

        if (end == -1) {
          throw StateError('parse method');
        }

        request.method = String.fromCharCodes(bytes.sublist(start, start = end));
        end = bytes.indexOf(32, start += 1);

        if (end == -1) {
          throw StateError('parse path');
        }

        var url = String.fromCharCodes(bytes.sublist(start, start = end));
        request.uri = Uri.parse(url);

        if (start + 9 != bytes.length ||
            bytes[start += 1] != 72 ||
            bytes[start += 1] != 84 ||
            bytes[start += 1] != 84 ||
            bytes[start += 1] != 80 ||
            bytes[start += 1] != 47 ||
            bytes[start += 1] != 49 ||
            bytes[start + 1] != 46) {
          throw StateError('parse version');
        }

        request.version = String.fromCharCodes(bytes.sublist(start));
        state = State.headers;
        return;

      case State.headers:
        if (bytes.isEmpty) {
          state = State.body;
          return;
        }

        var index = bytes.indexOf(58);

        if (index == -1) {
          throw StateError('header field: $index, ${utf8.decode(bytes)}');
        }

        var name = String.fromCharCodes(bytes.sublist(0, index));
        var value = String.fromCharCodes(bytes.sublist(index + 2));
        (request.headers ??= MutableHeaders()).add(name.toLowerCase(), value);
        break;

      case State.body:
        assert(false);
        return;
    }
  }

  void serve() {
    subscription
      ..pause()
      ..onDone(null)
      ..onDone(null);

    completer.complete(Request(socket, subscription, carry: carry));
  }
}

class PartialRequest {
  String? method;

  Uri? uri;

  String? version;

  MutableHeaders? headers;
}

class Request extends PartialRequest {
  Request(this.socket, this.subscription, {List<int>? carry}) : streamConsumed = false {
    if (carry != null) {
      getController(carry);
    }
  }

  @protected
  final Socket socket;

  @protected
  final StreamSubscription<List<int>> subscription;

  @protected
  StreamController<List<int>>? controller;

  @protected
  List<int>? consumedBody;

  bool streamConsumed;

  Future<List<int>> get body {
    List<int>? body = consumedBody;

    if (body != null) {
      return Future<List<int>>.value(body);
    }

    var stream = this.stream;
    body = consumedBody = <int>[];
    return stream.fold(body, (List<int> previous, List<int> element) {
      previous.addAll(element);
      return previous;
    });
  }

  IOSink get sink {
    return socket;
  }

  Stream<List<int>> get stream {
    var body = consumedBody;

    if (body != null) {
      return Stream<List<int>>.value(body);
    }

    if (streamConsumed) {
      throw StateError('stream consumed');
    }

    streamConsumed = true;
    return getController();
  }

  @protected
  Stream<List<int>> getController([List<int>? carry]) {
    var controller = this.controller;

    if (controller == null) {
      controller = StreamController<List<int>>(sync: true);

      if (carry != null) {
        controller.add(carry);
      }

      subscription
        ..onData(controller.add)
        ..onError(controller.addError)
        ..onDone(controller.close)
        ..resume();

      this.controller = controller;
    }

    return controller.stream;
  }
}

Future<void> main() async {
  const host = 'localhost';
  const port = 3000;

  var uri = Uri(scheme: 'http', host: host, port: port);
  var server = await ServerSocket.bind(host, port);

  scheduleMicrotask(() async {
    var response = await http.post(uri, body: 'ping');
    print(response.body);
    await server.close();
  });

  await for (var socket in server) {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    var parser = Parser(socket);
    var request = await parser.done;

    request.sink
      ..write('HTTP/1.1 200 OK')
      ..writeln()
      ..writeln()
      ..write('pong')
      ..close();

    var body = await request.body;
    print(utf8.decode(body));
  }
}
