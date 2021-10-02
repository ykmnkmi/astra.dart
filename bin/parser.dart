part of 'astra.dart';

const int lf = 10;
const int cr = 13;

class Parser extends Stream<List<int>> {
  Parser(this.socket)
      : controller = StreamController<List<int>>(sync: true),
        skipLeadingLF = false,
        newLinesCount = 0 {
    controller.onCancel = () {
      subscription?.cancel();
    };

    subscription = socket.listen(onData, onError: controller.addError, onDone: onDone);
  }

  final Socket socket;

  final StreamController<List<int>> controller;

  bool skipLeadingLF;

  // TODO: rename
  int newLinesCount;

  List<int>? carry;

  StreamSubscription<List<int>>? subscription;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void switchToBody(List<int>? rest) {
    var subscription = this.subscription;

    if (subscription != null) {
      subscription.pause();

      if (carry != null) {
        controller.add(carry!);
      }

      subscription.onData(controller.add);

      if (rest != null) {
        controller.add(rest);
      }

      subscription.resume();
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
            switchToBody(bytes.sublist(i + 1));
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
}
