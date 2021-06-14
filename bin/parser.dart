import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:astra/astra.dart';

class Constants {
  // Bytes for "HTTP".
  static const List<int> http = <int>[72, 84, 84, 80];
  // Bytes for "HTTP/1.".
  static const List<int> http1dot = <int>[72, 84, 84, 80, 47, 49, 46];
  // Bytes for "HTTP/1.0".
  static const List<int> http10 = <int>[72, 84, 84, 80, 47, 49, 46, 48];
  // Bytes for "HTTP/1.1".
  static const List<int> http11 = <int>[72, 84, 84, 80, 47, 49, 46, 49];

  static const bool T = true;

  static const bool F = false;
  // Loopup-map for the following characters: '()<>@,;:\\"/[]?={} \t'.
  static const List<bool> separatorMap = [
    F, F, F, F, F, F, F, F, F, T, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, T, F, T, F, F, F, F, F, T, T, F, F, T, F, F, T, //
    F, F, F, F, F, F, F, F, F, F, T, T, T, T, T, T, T, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, T, T, T, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, T, F, T, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F
  ];
}

// Frequently used character codes.
class CharCode {
  static const int ht = 9;
  static const int lf = 10;
  static const int cr = 13;
  static const int sp = 32;
  static const int ampersand = 38;
  static const int comma = 44;
  static const int dash = 45;
  static const int slash = 47;
  static const int zero = 48;
  static const int one = 49;
  static const int colon = 58;
  static const int semiColon = 59;
  static const int equal = 61;
}

// HTTP version of the request or response being parsed.
class HttpVersion {
  static const int undetermined = 0;
  static const int http10 = 1;
  static const int http11 = 2;
  static const int http2 = 3;
}

// States of the HTTP parser state machine.
class State {
  static const int start = 0;
  static const int method = 1;
  static const int uri = 2;
  static const int httpVersion = 3;
  static const int ending = 4;

  static const int headerStart = 5;
  static const int headerField = 6;
  static const int headerValueStart = 7;
  static const int headerValue = 8;
  static const int headerValueFoldOrEndCR = 9;
  static const int headerValueFoldOrEnd = 10;
  static const int headerEnding = 11;

  static const int chunkSizeStartingCR = 12;
  static const int chunkSizeStarting = 13;
  static const int chunkSize = 14;
  static const int chunkSizeExtension = 15;
  static const int chunkSizeEnding = 16;
  static const int chunkedBodyDoneCR = 17;
  static const int chunkedBodyDone = 18;

  static const int body = 19;
  static const int closed = 20;
  static const int upgraded = 21;
  static const int failure = 22;

  static const int firstBodyState = chunkSizeStartingCR;
}

abstract class Message {
  const Message([this.end = true]);

  final bool end;
}

class HeadersMessage extends Message {
  HeadersMessage(this.method, this.uri, this.headers, [bool end = false]) : super(end);

  final String method;

  final Uri uri;

  final Headers headers;
}

class DataMessage extends Message {
  DataMessage(this.bytes, [bool end = true]) : super(end);

  final List<int> bytes;
}

class Parser extends Stream<Message> {
  static const int chunkSizeLimit = 0x7FFFFFFF;

  static const int headerTotalSizeLimit = 1024 * 1024;

  Parser()
      : method = <int>[],
        uri = <int>[],
        headerField = <int>[],
        headerValue = <int>[],
        controller = StreamController<Message>(sync: true),
        parserCalled = false,
        state = State.start,
        index = -1,
        headersReceivedSize = 0,
        httpVersion = HttpVersion.undetermined,
        transferLength = -1,
        connectionUpgrade = false,
        chunked = false,
        remainingContent = -1,
        contentLength = false,
        transferEncoding = false,
        paused = true {
    controller
      ..onListen = () {
        paused = false;
      }
      ..onPause = () {
        paused = true;
        pauseStateChanged();
      }
      ..onResume = () {
        paused = false;
        pauseStateChanged();
      }
      ..onCancel = () {
        socketSubscription?.cancel();
      };
    reset();
  }

  final List<int> method;

  final List<int> uri;

  final List<int> headerField;

  final List<int> headerValue;

  final StreamController<Message> controller;

  bool parserCalled;

  Uint8List? buffer;

  int index;

  int state;

  int? httpVersionIndex;

  int headersReceivedSize;

  int httpVersion;

  int transferLength;

  bool connectionUpgrade;

  bool chunked;

  int remainingContent;

  bool contentLength;

  bool transferEncoding;

  MutableHeaders? headers;

  Message? message;

  StreamSubscription<Uint8List>? socketSubscription;

  bool paused;

  @override
  StreamSubscription<Message> listen(void Function(Message event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void listenToStream(Stream<Uint8List> stream) {
    socketSubscription = stream.listen(onData, onError: controller.addError, onDone: onDone);
  }

  void parse() {
    try {
      doParse();
    } catch (error, stackTrace) {
      if (state >= State.chunkSizeStartingCR && state <= State.body) {
        state = State.failure;
        reportError(error, stackTrace);
      } else {
        state = State.failure;
        reportError(error, stackTrace);
      }
    }
  }

  bool headersEnd() {
    // Ignore the Content-Length header if Transfer-Encoding
    // is chunked (RFC 2616 section 4.4)
    if (chunked) {
      transferLength = -1;
    } else {
      var headers = this.headers!;
      var transferLengthString = headers[Headers.contentLength];
      // If method is CONNECT, response parser should ignore any Content-Length or
      // Transfer-Encoding header fields in a successful response.
      // [RFC 7231](https://tools.ietf.org/html/rfc7231#section-4.3.6)
      transferLength = transferLengthString == null ? -1 : int.parse(transferLengthString);
    }

    // If a request message has neither Content-Length nor
    // Transfer-Encoding the message must not have a body (RFC
    // 2616 section 4.3).
    if (transferLength < 0 && chunked == false) {
      transferLength = 0;
    }

    if (connectionUpgrade) {
      state = State.upgraded;
      transferLength = 0;
    }

    var message = createMessage(String.fromCharCodes(method), Uri.parse(String.fromCharCodes(uri)), headers!);
    method.clear();
    uri.clear();

    if (connectionUpgrade) {
      parserCalled = false;
      closeIncoming();
      controller.add(message);
      return true;
    }

    if (transferLength == 0) {
      reset();
      closeIncoming();
      controller.add(message);
      return false;
    } else if (chunked) {
      state = State.chunkSize;
      remainingContent = 0;
    } else if (transferLength > 0) {
      remainingContent = transferLength;
      state = State.body;
    } else {
      // Neither chunked nor content length. End of body
      // indicated by close.
      state = State.body;
    }

    parserCalled = false;
    controller.add(message);
    return true;
  }

  // From RFC 2616.
  // generic-message = start-line
  //                   *(message-header CRLF)
  //                   CRLF
  //                   [ message-body ]
  // start-line      = Request-Line | Status-Line
  // Request-Line    = Method SP Request-URI SP HTTP-Version CRLF
  // Status-Line     = HTTP-Version SP Status-Code SP Reason-Phrase CRLF
  // message-header  = field-name ":" [ field-value ]
  //
  // Per section 19.3 "Tolerant Applications" CRLF treats LF as a terminator
  // and leading CR is ignored. Use of standalone CR is not allowed.

  void doParse() {
    assert(!parserCalled);

    parserCalled = true;

    if (state == State.closed) {
      throw HttpException('Data on closed connection');
    }
    if (state == State.failure) {
      throw HttpException('Data on failed connection');
    }

    while (this.buffer != null && index < this.buffer!.length && state != State.failure && state != State.upgraded) {
      if (message != null || (message == null && paused)) {
        parserCalled = false;
        return;
      }

      var index = this.index;
      var byte = this.buffer![index];
      this.index = index + 1;

      switch (state) {
        case State.start:
          // Start parsing method.
          if (!isTokenChar(byte)) {
            throw HttpException('Invalid request method');
          }

          addWithValidation(method, byte);
          state = State.method;
          break;

        case State.method:
          if (byte == CharCode.sp) {
            state = State.uri;
          } else {
            if (Constants.separatorMap[byte] || byte == CharCode.cr || byte == CharCode.lf) {
              throw HttpException('Invalid request method');
            }

            addWithValidation(method, byte);
          }

          break;

        case State.uri:
          if (byte == CharCode.sp) {
            if (uri.isEmpty) {
              throw HttpException('Invalid request, empty URI');
            }

            state = State.httpVersion;
            httpVersionIndex = 0;
          } else {
            if (byte == CharCode.cr || byte == CharCode.lf) {
              throw HttpException('Invalid request, unexpected $byte in URI');
            }

            addWithValidation(uri, byte);
          }

          break;

        case State.httpVersion:
          var httpVersionIndex = this.httpVersionIndex!;

          if (httpVersionIndex < Constants.http1dot.length) {
            expect(byte, Constants.http11[httpVersionIndex]);
            this.httpVersionIndex = httpVersionIndex + 1;
          } else if (this.httpVersionIndex == Constants.http1dot.length) {
            if (byte == CharCode.one) {
              // HTTP/1.1 parsed.
              httpVersion = HttpVersion.http11;
              this.httpVersionIndex = httpVersionIndex + 1;
            } else if (byte == CharCode.zero) {
              // HTTP/1.0 parsed.
              httpVersion = HttpVersion.http10;
              this.httpVersionIndex = httpVersionIndex + 1;
            } else {
              throw HttpException('Invalid HTTP version');
            }
          } else {
            state = State.ending;

            if (byte == CharCode.lf) {
              this.index = this.index - 1;
            }
          }

          break;

        case State.ending:
          expect(byte, CharCode.lf);
          state = State.headerStart;
          break;

        case State.headerStart:
          headers = MutableHeaders();

          if (byte == CharCode.cr) {
            state = State.headerEnding;
          } else if (byte == CharCode.lf) {
            state = State.headerEnding;
            this.index = this.index - 1;
          } else {
            addWithValidation(headerField, toLowerCaseByte(byte));
            state = State.headerField;
          }

          break;

        case State.headerField:
          if (byte == CharCode.colon) {
            state = State.headerValueStart;
          } else {
            if (!isTokenChar(byte)) {
              throw HttpException('Invalid header field name, with $byte');
            }

            addWithValidation(headerField, toLowerCaseByte(byte));
          }

          break;

        case State.headerValueStart:
          if (byte == CharCode.cr) {
            state = State.headerValueFoldOrEndCR;
          } else if (byte == CharCode.lf) {
            state = State.headerValueFoldOrEnd;
          } else if (byte != CharCode.sp && byte != CharCode.ht) {
            addWithValidation(headerValue, byte);
            state = State.headerValue;
          }

          break;

        case State.headerValue:
          if (byte == CharCode.cr) {
            state = State.headerValueFoldOrEndCR;
          } else if (byte == CharCode.lf) {
            state = State.headerValueFoldOrEnd;
          } else {
            addWithValidation(headerValue, byte);
          }

          break;

        case State.headerValueFoldOrEndCR:
          expect(byte, CharCode.lf);
          state = State.headerValueFoldOrEnd;
          break;

        case State.headerValueFoldOrEnd:
          if (byte == CharCode.sp || byte == CharCode.ht) {
            state = State.headerValueStart;
          } else {
            const errorIfBothText = 'Both Content-Length and Transfer-Encoding are specified, at most one is allowed';

            var headerField = String.fromCharCodes(this.headerField);
            var headerValue = String.fromCharCodes(this.headerValue);

            if (headerField == Headers.contentLength) {
              // Content Length header should not have more than one occurance
              // or coexist with Transfer Encoding header.
              if (contentLength) {
                throw HttpException('The Content-Length header occurred more than once, at most one is allowed.');
              } else if (transferEncoding) {
                throw HttpException(errorIfBothText);
              }

              contentLength = true;
            } else if (headerField == Headers.transferEncoding) {
              transferEncoding = true;

              if (caseInsensitiveCompare('chunked'.codeUnits, this.headerValue)) {
                chunked = true;
              }
              if (contentLength) {
                throw HttpException(errorIfBothText);
              }
            }

            var headers = this.headers!;

            if (headerField == Headers.connection) {
              var tokens = tokenizeFieldValue(headerValue);

              for (int i = 0; i < tokens.length; i++) {
                var isUpgrade = caseInsensitiveCompare('upgrade'.codeUnits, tokens[i].codeUnits);

                if (isUpgrade) {
                  connectionUpgrade = true;
                }

                headers.add(headerField, tokens[i]);
              }
            } else {
              headers.add(headerField, headerValue);
            }

            this.headerField.clear();
            this.headerValue.clear();

            if (byte == CharCode.cr) {
              state = State.headerEnding;
            } else if (byte == CharCode.lf) {
              state = State.headerEnding;
              this.index = this.index - 1; // Make the new state see the LF again.
            } else {
              // Start of new header field.
              state = State.headerField;
              addWithValidation(this.headerField, toLowerCaseByte(byte));
            }
          }

          break;

        case State.headerEnding:
          expect(byte, CharCode.lf);

          if (headersEnd()) {
            return;
          }

          break;

        case State.chunkSizeStartingCR:
          if (byte == CharCode.lf) {
            state = State.chunkSizeStarting;
            this.index = this.index - 1; // Make the new state see the LF again.
            break;
          }

          expect(byte, CharCode.cr);
          state = State.chunkSizeStarting;
          break;

        case State.chunkSizeStarting:
          expect(byte, CharCode.lf);
          state = State.chunkSize;
          break;

        case State.chunkSize:
          if (byte == CharCode.cr) {
            state = State.chunkSizeEnding;
          } else if (byte == CharCode.lf) {
            state = State.chunkSizeEnding;
            this.index = this.index - 1; // Make the new state see the LF again.
          } else if (byte == CharCode.semiColon) {
            state = State.chunkSizeExtension;
          } else {
            var value = expectHexDigit(byte);

            // Checks whether (_remaingingContent * 16 + value) overflows.
            if (remainingContent > chunkSizeLimit >> 4) {
              throw HttpException('Chunk size overflows the integer');
            }

            remainingContent = remainingContent * 16 + value;
          }

          break;

        case State.chunkSizeExtension:
          if (byte == CharCode.cr) {
            state = State.chunkSizeEnding;
          } else if (byte == CharCode.lf) {
            state = State.chunkSizeEnding;
            this.index = this.index - 1; // Make the new state see the LF again.
          }

          break;

        case State.chunkSizeEnding:
          expect(byte, CharCode.lf);

          if (remainingContent > 0) {
            state = State.body;
          } else {
            state = State.chunkedBodyDoneCR;
          }

          break;

        case State.chunkedBodyDoneCR:
          if (byte == CharCode.lf) {
            state = State.chunkedBodyDone;
            this.index = this.index - 1; // Make the new state see the LF again.
            break;
          }

          expect(byte, CharCode.cr);
          break;

        case State.chunkedBodyDone:
          expect(byte, CharCode.lf);
          reset();
          closeIncoming();
          break;

        case State.body:
          // The body is not handled one byte at a time but in blocks.
          this.index = this.index - 1;
          var buffer = this.buffer!;
          var dataAvailable = buffer.length - this.index;

          if (remainingContent >= 0 && dataAvailable > remainingContent) {
            dataAvailable = remainingContent;
          }

          // Always present the data as a view. This way we can handle all
          // cases like this, and the user will not experience different data
          // typed (which could lead to polymorphic user code).
          var data = Uint8List.view(buffer.buffer, buffer.offsetInBytes + this.index, dataAvailable);

          if (remainingContent != -1) {
            remainingContent -= data.length;
          }

          this.index = this.index + data.length;

          if (remainingContent == 0) {
            if (!chunked) {
              reset();
              closeIncoming();
            } else {
              state = State.chunkSizeStartingCR;
            }
          }

          break;

        case State.failure:
          assert(false, 'should be unreachable');
          break;

        default:
          assert(false, 'should be unreachable');
          break;
      }
    }

    parserCalled = false;
    var buffer = this.buffer;

    if (buffer != null && index == buffer.length) {
      // If all data is parsed release the buffer and resume receiving data.
      releaseBuffer();

      if (state != State.upgraded && state != State.failure) {
        socketSubscription!.resume();
      }
    }
  }

  void onData(Uint8List buffer) {
    socketSubscription!.pause();
    this.buffer = buffer;
    index = 0;
    parse();
  }

  void onDone() {
    // onDone cancels the subscription.
    socketSubscription = null;

    if (state == State.closed || state == State.failure) {
      return;
    }

    if (message != null) {
      closeIncoming(true);
      controller.close();
      return;
    }

    // If the connection is idle the HTTP stream is closed.
    if (state == State.start) {
      controller.close();
      return;
    }

    if (state == State.upgraded) {
      controller.close();
      return;
    }

    if (state < State.firstBodyState) {
      state = State.failure;
      reportError(HttpException('Connection closed before full header was received'));
      controller.close();
      return;
    }

    if (!chunked && transferLength == -1) {
      state = State.closed;
    } else {
      state = State.failure;
      reportError(HttpException('Connection closed before full body was received'));
    }

    controller.close();
  }

  void detach() {
    state = State.upgraded;
  }

  Uint8List? readUnparsedData() {
    var buffer = this.buffer;

    if (buffer == null) {
      return null;
    }

    var index = this.index;

    if (index == buffer.length) {
      return null;
    }

    var result = buffer.sublist(index);
    releaseBuffer();
    return result;
  }

  void reset() {
    if (state == State.upgraded) {
      return;
    }

    state = State.start;
    headerField.clear();
    headerValue.clear();
    headersReceivedSize = 0;
    method.clear();
    uri.clear();
    httpVersion = HttpVersion.undetermined;
    transferLength = -1;
    connectionUpgrade = false;
    chunked = false;
    remainingContent = -1;
    contentLength = false;
    transferEncoding = false;
    headers = null;
  }

  void releaseBuffer() {
    buffer = null;
    index = -1;
  }

  void expect(int val1, int val2) {
    if (val1 != val2) {
      throw HttpException('Failed to parse HTTP, $val1 does not match $val2');
    }
  }

  int expectHexDigit(int byte) {
    if (0x30 <= byte && byte <= 0x39) {
      return byte - 0x30; // 0 - 9
    }

    if (0x41 <= byte && byte <= 0x46) {
      return byte - 0x41 + 10; // A - F
    }

    if (0x61 <= byte && byte <= 0x66) {
      return byte - 0x61 + 10; // a - f
    }

    throw HttpException('Failed to parse HTTP, $byte is expected to be a Hex digit');
  }

  void addWithValidation(List<int> list, int byte) {
    headersReceivedSize++;

    if (headersReceivedSize < headerTotalSizeLimit) {
      list.add(byte);
    } else {
      reportSizeLimitError();
    }
  }

  void reportSizeLimitError() {
    var method = '';

    switch (state) {
      case State.start:
      case State.method:
        method = 'Method';
        break;

      case State.uri:
        method = 'URI';
        break;

      case State.headerStart:
      case State.headerField:
        method = 'Header field';
        break;

      case State.headerValueStart:
      case State.headerValue:
        method = 'Header value';
        break;

      default:
        throw UnsupportedError('Unexpected state: $state');
    }

    throw HttpException('$method exceeds the $headerTotalSizeLimit size limit');
  }

  Message createMessage(String method, Uri uri, Headers headers) {
    assert(this.message == null);

    var message = this.message = HeadersMessage(method, uri, headers, false);
    pauseStateChanged();
    return message;
  }

  void closeIncoming([bool closing = false]) {
    // Ignore multiple close (can happen in re-entrance).
    var temp = message;

    if (temp == null) {
      return;
    }

    message = null;
    pauseStateChanged();
  }

  void pauseStateChanged() {
    if (message != null) {
      if (!parserCalled) {
        parse();
      }
    } else {
      if (!paused && !parserCalled) {
        parse();
      }
    }
  }

  void reportError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;
    controller.addError(error, stackTrace);
    controller.close();
  }

  // expected should already be lowercase.
  static bool caseInsensitiveCompare(List<int> expected, List<int> value) {
    if (expected.length != value.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != toLowerCaseByte(value[i])) return false;
    }
    return true;
  }

  static bool isTokenChar(int byte) {
    return byte > 31 && byte < 128 && !Constants.separatorMap[byte];
  }

  static List<String> tokenizeFieldValue(String headerValue) {
    var tokens = <String>[];
    var start = 0;
    var index = 0;

    while (index < headerValue.length) {
      if (headerValue[index] == ",") {
        tokens.add(headerValue.substring(start, index));
        start = index + 1;
      } else if (headerValue[index] == " " || headerValue[index] == "\t") {
        start++;
      }

      index++;
    }

    tokens.add(headerValue.substring(start, index));
    return tokens;
  }

  static int toLowerCaseByte(int x) {
    // Optimized version:
    //  -  0x41 is 'A'
    //  -  0x7f is ASCII mask
    //  -  26 is the number of alpha characters.
    //  -  0x20 is the delta between lower and upper chars.
    return (((x - 0x41) & 0x7f) < 26) ? (x | 0x20) : x;
  }
}
