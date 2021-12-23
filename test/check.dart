import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;

const int lf = 10, cr = 13;

enum State {
  request,
  headers,
  body,
}

class Parser {
  Parser(this.socket) : subscription = socket.listen(null) {
    subscription
      ..pause()
      ..onData(onData)
      ..onDone(onDone)
      ..resume();
  }

  final Socket socket;

  final StreamSubscription<List<int>> subscription;

  final Completer<Request> completer = Completer<Request>.sync();

  List<int> carry = const <int>[];

  bool skipLeadingLF = false;

  int newLinesCount = 0;

  Future<Request> get done {
    return completer.future;
  }

  void addLines(List<int> bytes, int start) {
    int sliceStart = start, end = bytes.length;
    int char = 0;

    for (int i = start; i < end; i += 1) {
      int previousChar = char;
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
    int start = 0;

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

    serve();
  }

  void parse(List<int> bytes) {}

  void serve() {
    subscription
      ..pause()
      ..onDone(null)
      ..onDone(null);

    completer.complete(Request(socket, subscription, carry: carry));
  }
}

class Request extends Stream<List<int>> implements StreamSink<List<int>>, StringSink {
  Request(this.socket, StreamSubscription<List<int>> subscription, {List<int>? carry})
      : controller = StreamController<List<int>>(sync: true) {
    if (carry != null) {
      controller.add(carry);
    }

    subscription
      ..onData(controller.add)
      ..onError(controller.addError)
      ..onDone(controller.close)
      ..resume();
  }

  final Socket socket;

  final StreamController<List<int>> controller;

  @override
  Future<void> get done {
    return socket.done;
  }

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return controller.stream
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  void add(List<int> event) {
    socket.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    socket.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return socket.addStream(stream);
  }

  @override
  Future<void> close() {
    return socket.close();
  }

  @override
  void write(Object? object) {
    socket.write(object);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    socket.writeAll(objects);
  }

  @override
  void writeCharCode(int charCode) {
    socket.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    socket.writeln(object);
  }
}

void main() {
  const String host = 'localhost';
  const int port = 3000;

  final Uri uri = Uri(scheme: 'http', host: host, port: port);

  ServerSocket.bind(host, port).then<void>((ServerSocket server) {
    server.listen((Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }

      final Parser parser = Parser(socket);
      parser.done.then<void>((Request request) {
        print('request');
        request
          ..write('HTTP/1.1 200 OK')
          ..writeln()
          ..writeln()
          ..write('pong')
          ..close();
        utf8.decodeStream(request).then<void>(print);
      });
    });

    http.post(uri, body: 'ping').then<void>((Response response) {
      print('response');
      print(response.body);
      server.close();
    });
  });
}
