part of '../../http.dart';

class Constants {
  // 'HTTP'.
  static const List<int> http = <int>[72, 84, 84, 80];
  // 'HTTP/1.'.
  static const List<int> http1Dot = <int>[72, 84, 84, 80, 47, 49, 46];
  // 'HTTP/1.0'.
  static const List<int> http10 = <int>[72, 84, 84, 80, 47, 49, 46, 48];
  // 'HTTP/1.1'.
  static const List<int> http11 = <int>[72, 84, 84, 80, 47, 49, 46, 49];

  static const bool t = true, f = false;
  // Loopup-map for the following characters: '()<>@,;:\\"/[]?={} \t'.
  static const List<bool> sepatorMap = <bool>[
    f, f, f, f, f, f, f, f, f, t, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, t, f, t, f, f, f, f, f, t, t, f, f, t, f, f, t, //
    f, f, f, f, f, f, f, f, f, f, t, t, t, t, t, t, t, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, t, t, t, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, t, f, t, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, //
    f, f, f, f, f, f, f, f, f, f, f, f, f, f, f, f
  ];
}

// Frequently used character codes.
class CharCodes {
  static const int ht = 9;
  static const int lf = 10;
  static const int cr = 13;
  static const int sp = 32;
  static const int comma = 44;
  static const int splash = 47;
  static const int zero = 48;
  static const int one = 49;
  static const int colon = 58;
  static const int semiColon = 59;
}

// States of the HTTP parser state machine.
class State {
  static const int start = 0;
  static const int method = 3;
  static const int uri = 4;
  static const int version = 5;
  static const int requestLineEnding = 6;
  static const int headerStart = 10;
  static const int headerField = 11;
  static const int headerValueStart = 12;
  static const int headerValue = 13;
  static const int headerValueFoldOrEndCR = 14;
  static const int headerValueFoldOrEnd = 15;
  static const int headerEnding = 16;

  static const int chukSizeStartingCR = 17;
  static const int chunkSizeStarting = 18;
  static const int chunkSize = 19;
  static const int chunkSizeExtension = 20;
  static const int chunkSizeEnding = 21;
  static const int chunkedBodyDoneCR = 22;
  static const int chunkedBodyDone = 23;
  static const int body = 24;
  static const int closed = 25;
  static const int upgraded = 26;
  static const int failure = 27;

  static const int firstBodyState = chukSizeStartingCR;
}

// HTTP version of the request or response being parsed.
class HttpVersion {
  static const int undetermined = 0;
  static const int http10 = 1;
  static const int http11 = 2;
}

class DetachedStreamSubscription implements StreamSubscription<Uint8List> {
  DetachedStreamSubscription(this.subscription, this.injectData, this.userOnData);

  final StreamSubscription<Uint8List> subscription;

  Uint8List? injectData;

  void Function(Uint8List data)? userOnData;

  bool isCanceled = false;

  bool scheduled = false;

  int pauseCount = 1;

  @override
  bool get isPaused {
    return subscription.isPaused;
  }

  @override
  Future<T> asFuture<T>([T? futureValue]) {
    return subscription.asFuture<T>(futureValue as T);
  }

  @override
  Future<void> cancel() {
    isCanceled = true;
    injectData = null;
    return subscription.cancel();
  }

  @override
  void onData(void Function(Uint8List data)? handleData) {
    userOnData = handleData;
    subscription.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    subscription.onDone(handleDone);
  }

  @override
  void onError(Function? handleError) {
    subscription.onError(handleError);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    if (injectData == null) {
      subscription.pause(resumeSignal);
    } else {
      pauseCount += 1;

      if (resumeSignal != null) {
        resumeSignal.whenComplete(resume);
      }
    }
  }

  @override
  void resume() {
    if (injectData == null) {
      subscription.resume();
    } else {
      pauseCount -= 1;
      maybeScheduleData();
    }
  }

  void maybeScheduleData() {
    if (scheduled) {
      return;
    }

    if (pauseCount != 0) {
      return;
    }

    scheduled = true;

    scheduleMicrotask(() {
      scheduled = false;

      if (pauseCount > 0 || isCanceled) {
        return;
      }

      var data = injectData!;
      injectData = null;
      // To ensure that 'subscription.isPaused' is false, we resume the
      // subscription here. This is fine as potential events are delayed.
      subscription.resume();

      var userOnData = this.userOnData;

      if (userOnData != null) {
        userOnData(data);
      }
    });
  }
}

class DetachedIncoming extends Stream<Uint8List> {
  DetachedIncoming(this.subscription, this.bufferedData);

  final StreamSubscription<Uint8List>? subscription;

  final Uint8List? bufferedData;

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    var subscription = this.subscription;

    if (subscription != null) {
      subscription
        ..onData(onData)
        ..onError(onError)
        ..onDone(onDone);

      if (bufferedData == null) {
        subscription.resume();
        return subscription;
      }

      var detachedStreamSubscription = DetachedStreamSubscription(subscription, bufferedData, onData);
      detachedStreamSubscription.resume();
      return detachedStreamSubscription;
    }

    // TODO(26379): add test for this branch.
    return Stream<Uint8List>.value(bufferedData!).listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }
}

class Parser extends Stream<Incoming> {
  static const int headerTotalSizeLimit = 1024 * 1024;

  static const int chunkSizeLimit = 0x7FFFFFFF;

  Parser() : controller = StreamController<Incoming>(sync: true) {
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

  // State.
  bool parserCalled = false;

  // The data that is currently being parsed.
  Uint8List? buffer;
  int index = -1;

  int state = State.start;
  int? versionIndex;
  bool requestDetermined = false;
  final List<int> methodBuffer = [];
  final List<int> uriBuffer = [];
  final List<int> headerFieldBuffer = [];
  final List<int> headerValueBuffer = [];
  int headersReceivedSize = 0;

  int httpVersion = HttpVersion.undetermined;
  int transferLength = -1;
  bool connectionUpgrade = false;
  bool chunked = false;

  int remainingContent = -1;
  bool contentLength = false;
  bool transferEncoding = false;
  bool connectMethod = false;

  Headers? headers;

  Incoming? incoming;
  StreamSubscription<Uint8List>? socketSubscription;
  bool paused = true;
  bool bodyPaused = false;
  final StreamController<Incoming> controller;
  StreamController<Uint8List>? bodyController;

  void listenToStream(Stream<Uint8List> stream) {
    // Listen to the stream and handle data accordingly. When a
    // Incoming is created, _dataPause, _dataResume, _dataDone is
    // given to provide a way of controlling the parser.
    // TODO(ajohnsen): Remove _dataPause, _dataResume and _dataDone and clean up
    // how the Incoming signals the parser.
    socketSubscription = stream.listen(onData, onError: controller.addError, onDone: onDone);
  }

  @override
  StreamSubscription<Incoming> listen(void Function(Incoming event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    return controller.stream.listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }

  void parse() {
    try {
      doParse();
    } catch (error, stackTrace) {
      if (state >= State.chukSizeStartingCR && state <= State.body) {
        state = State.failure;
        reportBodyError(error, stackTrace);
      } else {
        state = State.failure;
        reportHttpError(error, stackTrace);
      }
    }
  }

  // Process end of headers. Returns true if the parser should stop
  // parsing and return. This will be in case of either an upgrade
  // request or a request or response with an empty body.
  bool headersEnd() {
    var headers = this.headers!;

    // If method is CONNECT, response parser should ignore any Content-Length or
    // Transfer-Encoding header fields in a successful response.
    // [RFC 7231](https://tools.ietf.org/html/rfc7231#section-4.3.6)
    transferLength = headers.contentLength;

    // Ignore the Content-Length header if Transfer-Encoding
    // is chunked (RFC 2616 section 4.4)
    if (chunked) {
      transferLength = -1;
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

    var incoming = createIncoming(transferLength);
    incoming.method = String.fromCharCodes(methodBuffer);
    incoming.uri = Uri.parse(String.fromCharCodes(uriBuffer));
    methodBuffer.clear();
    uriBuffer.clear();

    if (connectionUpgrade) {
      incoming.upgraded = true;
      parserCalled = false;
      closeIncoming();
      controller.add(incoming);
      return true;
    }

    if (transferLength == 0) {
      reset();
      closeIncoming();
      controller.add(incoming);
      return false;
    }

    if (chunked) {
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
    controller.add(incoming);
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
      // Depending on incoming, we either break on bodyPaused or paused.
      if ((incoming != null && bodyPaused) || (incoming == null && paused)) {
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

          addWithValidation(methodBuffer, byte);
          state = State.method;
          break;

        case State.method:
          if (byte == CharCodes.sp) {
            state = State.uri;
          } else {
            if (Constants.sepatorMap[byte] || byte == CharCodes.cr || byte == CharCodes.lf) {
              throw HttpException('Invalid request method');
            }

            addWithValidation(methodBuffer, byte);
          }

          break;

        case State.uri:
          if (byte == CharCodes.sp) {
            if (uriBuffer.isEmpty) {
              throw HttpException('Invalid request, empty URI');
            }

            state = State.version;
            versionIndex = 0;
          } else {
            if (byte == CharCodes.cr || byte == CharCodes.lf) {
              throw HttpException('Invalid request, unexpected $byte in URI');
            }

            addWithValidation(uriBuffer, byte);
          }

          break;

        case State.version:
          var versionIndex = this.versionIndex!;

          if (versionIndex < Constants.http1Dot.length) {
            expect(byte, Constants.http11[versionIndex]);
            this.versionIndex = versionIndex + 1;
          } else if (this.versionIndex == Constants.http1Dot.length) {
            if (byte == CharCodes.one) {
              // HTTP/1.1 parsed.
              httpVersion = HttpVersion.http11;
              this.versionIndex = versionIndex + 1;
            } else if (byte == CharCodes.zero) {
              // HTTP/1.0 parsed.
              httpVersion = HttpVersion.http10;
              this.versionIndex = versionIndex + 1;
            } else {
              throw HttpException('Invalid response, invalid HTTP version');
            }
          } else {
            if (byte == CharCodes.cr) {
              state = State.requestLineEnding;
            } else if (byte == CharCodes.lf) {
              state = State.requestLineEnding;
              this.index = this.index - 1;
            }
          }

          break;

        case State.requestLineEnding:
          expect(byte, CharCodes.lf);
          requestDetermined = true;
          state = State.headerStart;
          break;

        case State.headerStart:
          headers = Headers(version!);

          if (byte == CharCodes.cr) {
            state = State.headerEnding;
          } else if (byte == CharCodes.lf) {
            state = State.headerEnding;
            this.index = this.index - 1;
          } else {
            addWithValidation(headerFieldBuffer, toLowerCaseByte(byte));
            state = State.headerField;
          }

          break;

        case State.headerField:
          if (byte == CharCodes.colon) {
            state = State.headerValueStart;
          } else {
            if (!isTokenChar(byte)) {
              throw HttpException('Invalid header field name, with $byte');
            }

            addWithValidation(headerFieldBuffer, toLowerCaseByte(byte));
          }

          break;

        case State.headerValueStart:
          if (byte == CharCodes.cr) {
            state = State.headerValueFoldOrEndCR;
          } else if (byte == CharCodes.lf) {
            state = State.headerValueFoldOrEnd;
          } else if (byte != CharCodes.sp && byte != CharCodes.ht) {
            addWithValidation(headerValueBuffer, byte);
            state = State.headerValue;
          }

          break;

        case State.headerValue:
          if (byte == CharCodes.cr) {
            state = State.headerValueFoldOrEndCR;
          } else if (byte == CharCodes.lf) {
            state = State.headerValueFoldOrEnd;
          } else {
            addWithValidation(headerValueBuffer, byte);
          }

          break;

        case State.headerValueFoldOrEndCR:
          expect(byte, CharCodes.lf);
          state = State.headerValueFoldOrEnd;
          break;

        case State.headerValueFoldOrEnd:
          if (byte == CharCodes.sp || byte == CharCodes.ht) {
            state = State.headerValueStart;
          } else {
            const errorIfBothText = 'Both Content-Length and Transfer-Encoding are specified, at most one is allowed';

            validateField(headerFieldBuffer);
            validateValue(headerValueBuffer);

            var field = String.fromCharCodes(headerFieldBuffer);
            var value = String.fromCharCodes(headerValueBuffer);

            if (field == HttpHeaders.contentLengthHeader) {
              // Content Length header should not have more than one occurrence
              // or coexist with Transfer Encoding header.
              if (contentLength) {
                throw HttpException('The Content-Length header occurred more than once, at most one is allowed.');
              } else if (transferEncoding) {
                throw HttpException(errorIfBothText);
              }

              contentLength = true;
            } else if (field == HttpHeaders.transferEncodingHeader) {
              transferEncoding = true;

              if (caseInsensitiveCompare('chunked'.codeUnits, headerValueBuffer)) {
                chunked = true;
              }

              if (contentLength) {
                throw HttpException(errorIfBothText);
              }
            }

            var headers = this.headers!;
            var values = headers[field] ??= <String>[];

            if (field == HttpHeaders.connectionHeader) {
              var tokens = tokenizeFieldValue(value);

              for (var token in tokens) {
                if ((caseInsensitiveCompare('upgrade'.codeUnits, token.codeUnits))) {
                  connectionUpgrade = true;
                }

                values.add(token);
              }
            } else {
              values.add(value);
            }

            headerFieldBuffer.clear();
            headerValueBuffer.clear();

            if (byte == CharCodes.cr) {
              state = State.headerEnding;
            } else if (byte == CharCodes.lf) {
              state = State.headerEnding;
              this.index = this.index - 1;
            } else {
              state = State.headerField;
              addWithValidation(headerFieldBuffer, toLowerCaseByte(byte));
            }
          }

          break;

        case State.headerEnding:
          expect(byte, CharCodes.lf);

          if (headersEnd()) {
            return;
          }

          break;

        case State.chukSizeStartingCR:
          if (byte == CharCodes.lf) {
            state = State.chunkSizeStarting;
            this.index = this.index - 1;
            break;
          }

          expect(byte, CharCodes.cr);
          state = State.chunkSizeStarting;
          break;

        case State.chunkSizeStarting:
          expect(byte, CharCodes.lf);
          state = State.chunkSize;
          break;

        case State.chunkSize:
          if (byte == CharCodes.cr) {
            state = State.chunkSizeEnding;
          } else if (byte == CharCodes.lf) {
            state = State.chunkSizeEnding;
            this.index = this.index - 1;
          } else if (byte == CharCodes.semiColon) {
            state = State.chunkSizeExtension;
          } else {
            var value = expectHexDigit(byte);

            // Checks whether (remainingContent * 16 + value) overflows.
            if (remainingContent > chunkSizeLimit >> 4) {
              throw HttpException('Chunk size overflows the integer');
            }

            remainingContent = remainingContent * 16 + value;
          }

          break;

        case State.chunkSizeExtension:
          if (byte == CharCodes.cr) {
            state = State.chunkSizeEnding;
          } else if (byte == CharCodes.lf) {
            state = State.chunkSizeEnding;
            this.index = this.index - 1;
          }

          break;

        case State.chunkSizeEnding:
          expect(byte, CharCodes.lf);

          if (remainingContent > 0) {
            state = State.body;
          } else {
            state = State.chunkedBodyDoneCR;
          }

          break;

        case State.chunkedBodyDoneCR:
          if (byte == CharCodes.lf) {
            state = State.chunkedBodyDone;
            this.index = this.index - 1;
            break;
          }

          expect(byte, CharCodes.cr);
          break;

        case State.chunkedBodyDone:
          expect(byte, CharCodes.lf);
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
          bodyController!.add(data);

          if (remainingContent != -1) {
            remainingContent -= data.length;
          }

          this.index = this.index + data.length;

          if (remainingContent == 0) {
            if (!chunked) {
              reset();
              closeIncoming();
            } else {
              state = State.chukSizeStartingCR;
            }
          }

          break;

        case State.failure:
          // Should be unreachable.
          assert(false);
          break;

        default:
          // Should be unreachable.
          assert(false);
          break;
      }
    }

    parserCalled = false;

    var buffer = this.buffer;

    if (buffer != null && index == buffer.length) {
      // If all data is parsed release the buffer and resume receiving
      // data.
      releaseBuffer();

      if (state != State.upgraded && state != State.failure) {
        socketSubscription!.resume();
      }
    }
  }

  void onData(Uint8List buffer) {
    socketSubscription!.pause();

    assert(this.buffer == null);

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

    if (incoming != null) {
      if (state != State.upgraded && !(state == State.body && !chunked && transferLength == -1)) {
        reportBodyError(HttpException('Connection closed while receiving data'));
      }

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
      // Report the error through the error callback if any. Otherwise
      // throw the error.
      reportHttpError(HttpException('Connection closed before full header was received'));
      controller.close();
      return;
    }

    if (!chunked && transferLength == -1) {
      state = State.closed;
    } else {
      state = State.failure;
      // Report the error through the error callback if any. Otherwise
      // throw the error.
      reportHttpError(HttpException('Connection closed before full body was received'));
    }

    controller.close();
  }

  String? get version {
    switch (httpVersion) {
      case HttpVersion.http10:
        return '1.0';
      case HttpVersion.http11:
        return '1.1';
    }

    return null;
  }

  bool get upgrade {
    return connectionUpgrade && state == State.upgraded;
  }

  DetachedIncoming detachIncoming() {
    // Simulate detached by marking as upgraded.
    state = State.upgraded;
    return DetachedIncoming(socketSubscription, readUnparsedData());
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
    requestDetermined = false;
    headerFieldBuffer.clear();
    headerValueBuffer.clear();
    headersReceivedSize = 0;
    methodBuffer.clear();
    uriBuffer.clear();

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

  static bool isTokenChar(int byte) {
    return byte > 31 && byte < 128 && !Constants.sepatorMap[byte];
  }

  static bool isValueChar(int byte) {
    return byte > 31 && byte < 128 || byte == CharCodes.ht;
  }

  static List<String> tokenizeFieldValue(String headerValue) {
    var tokens = <String>[];
    var start = 0;
    var index = 0;

    while (index < headerValue.length) {
      if (headerValue[index] == ',') {
        tokens.add(headerValue.substring(start, index));
        start = index + 1;
      } else if (headerValue[index] == ' ' || headerValue[index] == '\t') {
        start += 1;
      }

      index += 1;
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

  // expected should already be lowercase.
  static bool caseInsensitiveCompare(List<int> expected, List<int> value) {
    if (expected.length != value.length) {
      return false;
    }

    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != toLowerCaseByte(value[i])) {
        return false;
      }
    }

    return true;
  }

  static void expect(int got, int expected) {
    if (got != expected) {
      throw HttpException('Failed to parse HTTP, $got does not match $expected');
    }
  }

  static int expectHexDigit(int byte) {
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
    headersReceivedSize += 1;

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

  Incoming createIncoming(int transferLength) {
    assert(this.incoming == null);
    assert(bodyController == null);
    assert(!bodyPaused);

    var controller = bodyController = StreamController<Uint8List>(sync: true);
    var incoming = this.incoming = Incoming(headers!, transferLength, controller.stream);

    controller
      ..onListen = () {
        if (incoming != this.incoming) {
          return;
        }

        assert(bodyPaused);

        bodyPaused = false;
        pauseStateChanged();
      }
      ..onPause = () {
        if (incoming != this.incoming) {
          return;
        }

        assert(!bodyPaused);

        bodyPaused = true;
        pauseStateChanged();
      }
      ..onResume = () {
        if (incoming != this.incoming) {
          return;
        }

        assert(bodyPaused);

        bodyPaused = false;
        pauseStateChanged();
      }
      ..onCancel = () {
        if (incoming != this.incoming) {
          return;
        }

        socketSubscription?.cancel();
        closeIncoming(true);
        this.controller.close();
      };

    bodyPaused = true;
    pauseStateChanged();
    return incoming;
  }

  void closeIncoming([bool closing = false]) {
    // Ignore multiple close (can happen in re-entrance).
    var incoming = this.incoming;

    if (incoming == null) {
      return;
    }

    incoming.close(closing);
    incoming = null;

    var controller = bodyController;

    if (controller != null) {
      controller.close();
      bodyController = null;
    }

    bodyPaused = false;
    pauseStateChanged();
  }

  void pauseStateChanged() {
    if (incoming != null) {
      if (!bodyPaused && !parserCalled) {
        parse();
      }
    } else {
      if (!paused && !parserCalled) {
        parse();
      }
    }
  }

  void reportHttpError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;
    controller.addError(error, stackTrace);
    controller.close();
  }

  void reportBodyError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;

    var bodyController = this.bodyController;

    // In case of drain(), error event will close the stream.
    bodyController
      ?..addError(error, stackTrace)
      ..close();
  }

  static void validateField(List<int> bytes) {
    for (var i = 0; i < bytes.length; i += 1) {
      if (!Parser.isTokenChar(bytes[i])) {
        var field = String.fromCharCodes(bytes);
        throw FormatException('Invalid HTTP header field name: ${json.encode(field)}', field, i);
      }
    }
  }

  static void validateValue(List<int> bytes) {
    for (var i = 0; i < bytes.length; i += 1) {
      if (!Parser.isValueChar(bytes[i])) {
        var field = String.fromCharCodes(bytes);
        throw FormatException('Invalid HTTP header field value: ${json.encode(field)}', field, i);
      }
    }
  }
}
