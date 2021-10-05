part of 'server.dart';

const int lf = 10;
const int cr = 13;

enum _State {
  request,
  headers,
}

class _Parser extends Stream<List<int>> {
  _Parser(this.socket, this.sink)
      : controller = StreamController<List<int>>(sync: true),
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
        ..onData(sink.add)
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

  static Future<_Connection> parse(Socket socket) {
    if (socket.address.type != InternetAddressType.unix) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    var controller = StreamController<List<int>>();
    var completer = Completer<_Connection>.sync();
    var connection = _Connection(controller.stream, socket);
    var state = _State.request;

    _Parser(socket, controller.sink).listen((bytes) {
      if (bytes.isEmpty) {
        completer.complete(connection);
        return;
      }

      switch (state) {
        // TODO: update errors
        case _State.request:
          var start = 0, end = bytes.indexOf(32);
          if (end == -1) throw Exception('method');
          connection.method =
              String.fromCharCodes(bytes.sublist(start, start = end));
          end = bytes.indexOf(32, start += 1);
          if (end == -1) throw Exception('uri');
          connection.url = Uri.parse(
              String.fromCharCodes(bytes.sublist(start, start = end)));
          if (start + 9 != bytes.length) throw Exception('version');
          if (bytes[start += 1] != 72) throw Exception('version H');
          if (bytes[start += 1] != 84) throw Exception('version HT');
          if (bytes[start += 1] != 84) throw Exception('version HTT');
          if (bytes[start += 1] != 80) throw Exception('version HTTP');
          if (bytes[start += 1] != 47) throw Exception('version HTTP/');
          if (bytes[start += 1] != 49) throw Exception('version HTTP/1');
          if (bytes[start + 1] != 46) throw Exception('version HTTP/1.');
          connection.version = String.fromCharCodes(bytes.sublist(start));
          state = _State.headers;
          break;
        case _State.headers:
          var index = bytes.indexOf(58);
          if (index == -1) throw Exception('header field');
          var name = String.fromCharCodes(bytes.sublist(0, index));
          var value = String.fromCharCodes(bytes.sublist(index + 2));
          connection.headers.add(name, value);
          break;
      }
    }, onError: completer.completeError);
    return completer.future;
  }
}
