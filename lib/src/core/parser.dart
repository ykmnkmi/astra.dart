import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io' show Socket;
import 'dart:typed_data' show Uint8List;

const int lf = 10;
const int cr = 13;

class Parser extends Stream<Uint8List> {
  Parser(this.socket, this.sink)
      : controller = StreamController<Uint8List>(sync: true),
        skipLeadingLF = false,
        newLinesCount = 0 {
    subscription =
        socket.listen(onData, onError: controller.addError, onDone: onDone);
  }

  final Socket socket;

  final Sink<List<int>> sink;

  final StreamController<Uint8List> controller;

  bool skipLeadingLF;

  int newLinesCount;

  Uint8List? carry;

  StreamSubscription<List<int>>? subscription;

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
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

  void addLines(Uint8List bytes, int start) {
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

  void onData(Uint8List bytes) {
    var start = 0;

    if (carry != null) {
      assert(!skipLeadingLF);
      bytes = carry! + bytes.sublist(start) as Uint8List;
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
}
