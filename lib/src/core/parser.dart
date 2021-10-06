import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io' show InternetAddressType, Socket, SocketOption;

import 'package:astra/core.dart';

import 'request.dart';

const int lf = 10;
const int cr = 13;

enum State {
  request,
  headers,
}

class Parser extends Stream<List<int>> {
  Parser(this.socket, this.sink)
      : controller = StreamController<List<int>>(),
        skipLeadingLF = false,
        newLinesCount = 0 {
    subscription =
        socket.listen(onData, onError: controller.addError, onDone: onDone);
  }

  final Socket socket;

  final Sink<List<int>> sink;

  final StreamController<List<int>> controller;

  bool skipLeadingLF;

  int newLinesCount;

  List<int>? carry;

  StreamSubscription<List<int>>? subscription;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void switchToBody() {
    var subscription = this.subscription;

    if (subscription != null) {
      subscription.pause();

      if (carry != null) {
        controller.add(carry!);
      }

      controller.close();
      subscription
        ..onData(socket.add)
        ..resume();
    }
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
            switchToBody();
            return;
          } else {
            sliceStart = i + 1;
            continue;
          }
        }
      }

      controller.add(bytes.sublist(sliceStart, i));
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

    if (carry != null) {
      assert(!skipLeadingLF);
      bytes = carry! + bytes.sublist(start);
      start = 0;
      carry = null;
    } else if (skipLeadingLF) {
      if (bytes[start] == lf) {
        start += 1;
      }

      skipLeadingLF = false;
    }

    addLines(bytes, start);
  }

  void onDone() {
    if (carry != null) {
      controller.add(carry!);
    }

    subscription = null;
  }

  static Future<RequestImpl> parse(Server server, Socket socket) async {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    var controller = StreamController<List<int>>();
    var state = State.request;

    late String method;
    late String url;
    late String version;
    var headers = MutableHeaders();

    await for (var bytes in Parser(socket, controller.sink)) {
      if (bytes.isEmpty) {
        break;
      }

      // TODO: update errors
      switch (state) {
        case State.request:
          var start = 0, end = bytes.indexOf(32);
          if (end == -1) throw Exception('method');
          method = String.fromCharCodes(bytes.sublist(start, start = end));
          end = bytes.indexOf(32, start += 1);
          if (end == -1) throw Exception('uri');
          url = String.fromCharCodes(bytes.sublist(start, start = end));
          if (start + 9 != bytes.length) throw Exception('version');
          if (bytes[start += 1] != 72) throw Exception('version H');
          if (bytes[start += 1] != 84) throw Exception('version HT');
          if (bytes[start += 1] != 84) throw Exception('version HTT');
          if (bytes[start += 1] != 80) throw Exception('version HTTP');
          if (bytes[start += 1] != 47) throw Exception('version HTTP/');
          if (bytes[start += 1] != 49) throw Exception('version HTTP/1');
          if (bytes[start + 1] != 46) throw Exception('version HTTP/1.');
          version = String.fromCharCodes(bytes.sublist(start));
          state = State.headers;
          break;
        case State.headers:
          var index = bytes.indexOf(58);
          if (index == -1) throw Exception('header field');
          var name = String.fromCharCodes(bytes.sublist(0, index));
          var value = String.fromCharCodes(bytes.sublist(index + 2));
          headers.add(name, value);
          break;
        default:
          throw UnimplementedError();
      }
    }

    void start(int status, {List<Header>? headers}) {
      socket.writeln('HTTP/$version $status ${ReasonPhrases.to(status)}');

      if (headers != null) {
        for (var header in headers) {
          socket.writeln('$header');
        }
      }

      socket.writeln();
    }

    void send(List<int> bytes) {
      socket.add(bytes);
    }

    Future<void> flush() {
      return socket.flush();
    }

    Future<void> close() {
      return socket.close();
    }

    return RequestImpl(controller.stream, socket, method, Uri.parse(url),
        version, headers, start, send, flush, close);
  }
}
