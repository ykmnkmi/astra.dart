import 'dart:async' show EventSink, StreamTransformerBase;
import 'dart:convert' show ByteConversionSink, ByteConversionSinkBase;

const int lf = 10;
const int cr = 13;

class LineSplitterSink extends ByteConversionSinkBase {
  LineSplitterSink(this.sink) : skipLeadingLF = false;

  final ByteConversionSink sink;

  bool skipLeadingLF;

  List<int>? carry;

  @override
  void add(List<int> chunk) {
    addSlice(chunk, 0, chunk.length, false);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    end = RangeError.checkValidRange(start, end, chunk.length);

    if (start >= end) {
      if (isLast) close();
      return;
    }

    final carry = this.carry;

    if (carry != null) {
      assert(!skipLeadingLF);
      chunk = carry + chunk.sublist(start, end);
      start = 0;
      end = chunk.length;
      this.carry = null;
    } else if (skipLeadingLF) {
      if (chunk[start] == lf) {
        start += 1;
      }

      skipLeadingLF = false;
    }

    addLines(chunk, start, end);

    if (isLast) {
      close();
    }
  }

  @override
  void close() {
    final carry = this.carry;

    if (carry != null) {
      sink.add(carry);
      this.carry = null;
    }

    sink.close();
  }

  void addLines(List<int> lines, int start, int end) {
    var sliceStart = start;
    var char = 0;

    for (var i = start; i < end; i++) {
      var previousChar = char;
      char = lines[i];

      if (char != cr) {
        if (char != lf) {
          continue;
        }

        if (previousChar == cr) {
          sliceStart = i + 1;
          continue;
        }
      }

      sink.add(lines.sublist(sliceStart, i));
      sliceStart = i + 1;
    }

    if (sliceStart < end) {
      carry = lines.sublist(sliceStart, end);
    } else {
      skipLeadingLF = char == cr;
    }
  }
}

class LineSplitterEventSink extends LineSplitterSink
    implements EventSink<List<int>> {
  LineSplitterEventSink(this.eventSink)
      : super(ByteConversionSink.from(eventSink));

  final EventSink<List<int>> eventSink;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    eventSink.addError(error, stackTrace);
  }
}

class LineSplitter extends StreamTransformerBase<List<int>, List<int>> {
  const LineSplitter();

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) {
    return Stream<List<int>>.eventTransformed(
        stream, LineSplitterEventSink.new);
  }
}
