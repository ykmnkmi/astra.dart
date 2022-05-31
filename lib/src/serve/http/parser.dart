part of astra.serve.http;

class Constants {
  static const List<int> http = <int>[72, 84, 84, 80];

  static const List<int> http1dot = <int>[72, 84, 84, 80, 47, 49, 46];

  static const List<int> http10 = <int>[72, 84, 84, 80, 47, 49, 46, 48];

  static const List<int> http11 = <int>[72, 84, 84, 80, 47, 49, 46, 49];

  static const bool t = true, f = false;

  static const List<bool> separatorMap = <bool>[
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

class CharCodes {
  static const int ht = 9, lf = 10, cr = 13, sp = 32;

  static const int comma = 44, slash = 47;

  static const int zero = 48, one = 49;

  static const int colon = 58, semiColon = 59;
}

abstract class State {
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
  static const int chunkSizeStartingCR = 17;
  static const int chunkSizeStarting = 18;
  static const int chunkSize = 19;
  static const int chunkSizeExtension = 20;
  static const int chunkSizeEnding = 21;
  static const int chunkedBodyDoneCR = 22;
  static const int chunkedBodyDone = 23;
  static const int body = 24;
  static const int closed = 25;
  static const int upgaded = 26;
  static const int failure = 27;
  static const int firstBodyState = chunkSizeStartingCR;
}

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
    return subscription.asFuture<T>(futureValue);
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
      pauseCount--;
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
      subscription.resume();
      userOnData?.call(data);
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
        return subscription..resume();
      }

      var detachedSubscription = DetachedStreamSubscription(subscription, bufferedData, onData);
      detachedSubscription.resume();
      return detachedSubscription;
    }

    // TODO(26379): add test for this branch.
    return Stream<Uint8List>.value(bufferedData!).listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }
}

class Parser extends Stream<Incoming> {
  // The limit for parsing chunk size
  static const int chunkSizeLimit = 0x7FFFFFFF;

  // State.
  bool parserCalled = false;

  // The data that is currently being parsed.
  Uint8List? buffer;
  int index = -1;

  int state = State.start;
  int? versionIndex;
  final List<int> method = [];
  final List<int> uri = [];
  final List<int> headerField = [];
  final List<int> headerValue = [];
  static const headerTotalSizeLimit = 1024 * 1024;
  int headersReceivedSize = 0;

  int httpVersion = HttpVersion.undetermined;
  int transferLength = -1;
  bool persistentConnection = false;
  bool connectionUpgrade = false;
  bool chunked = false;

  int remainingContent = -1;
  bool contentLength = false;
  bool transferEncoding = false;
  bool connectMethod = false;

  Headers? headers;

  // The current incoming connection.
  Incoming? incoming;
  StreamSubscription<Uint8List>? socketSubscription;
  bool paused = true;
  bool bodyPaused = false;
  final StreamController<Incoming> controller;
  StreamController<Uint8List>? bodyController;

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

  void listenToStream(Stream<Uint8List> stream) {
    // Listen to the stream and handle data accordingly. When a
    // _HttpIncoming is created, _dataPause, _dataResume, _dataDone is
    // given to provide a way of controlling the parser.
    // TODO(ajohnsen): Remove _dataPause, _dataResume and _dataDone and clean up
    // how the _HttpIncoming signals the parser.
    socketSubscription = stream.listen(onData, onError: controller.addError, onDone: onDone);
  }

  void parse() {
    try {
      doParse();
    } catch (error, stackTrace) {
      if (state >= State.chunkSizeStartingCR && state <= State.body) {
        state = State.failure;
        reportBodyError(error, stackTrace);
      } else {
        state = State.failure;
        reportHttpError(error, stackTrace);
      }
    }
  }

  bool headersEnd() {
    var headers = this.headers!;
    headers.mutable = false;
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
      state = State.upgaded;
      transferLength = 0;
    }

    var incoming = createIncoming(transferLength);
    incoming.method = String.fromCharCodes(method);
    incoming.uri = Uri.parse(String.fromCharCodes(uri));
    method.clear();
    uri.clear();

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

    while (this.buffer != null &&
        index < this.buffer!.length &&
        state != State.failure &&
        state != State.upgaded) {
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

          addWithValidation(method, byte);
          state = State.method;
          break;

        case State.method:
          if (byte == CharCodes.sp) {
            state = State.uri;
          } else {
            if (Constants.separatorMap[byte] || byte == CharCodes.cr || byte == CharCodes.lf) {
              throw HttpException('Invalid request method');
            }

            addWithValidation(method, byte);
          }

          break;

        case State.uri:
          if (byte == CharCodes.sp) {
            if (uri.isEmpty) {
              throw HttpException('Invalid request, empty URI');
            }

            state = State.version;
            versionIndex = 0;
          } else {
            if (byte == CharCodes.cr || byte == CharCodes.lf) {
              throw HttpException('Invalid request, unexpected $byte in URI');
            }

            addWithValidation(uri, byte);
          }

          break;

        case State.version:
          var httpVersionIndex = versionIndex!;

          if (httpVersionIndex < Constants.http1dot.length) {
            expect(byte, Constants.http11[httpVersionIndex]);
            versionIndex = httpVersionIndex + 1;
          } else if (versionIndex == Constants.http1dot.length) {
            if (byte == CharCodes.one) {
              // HTTP/1.1 parsed.
              httpVersion = HttpVersion.http11;
              persistentConnection = true;
              versionIndex = httpVersionIndex + 1;
            } else if (byte == CharCodes.zero) {
              // HTTP/1.0 parsed.
              httpVersion = HttpVersion.http10;
              persistentConnection = false;
              versionIndex = httpVersionIndex + 1;
            } else {
              throw HttpException('Invalid response, invalid HTTP version');
            }
          } else {
            if (byte == CharCodes.cr) {
              state = State.requestLineEnding;
            } else if (byte == CharCodes.lf) {
              state = State.requestLineEnding;
              this.index = this.index - 1; // Make the new state see the LF again.
            }
          }

          break;

        case State.requestLineEnding:
          expect(byte, CharCodes.lf);
          state = State.headerStart;
          break;

        case State.headerStart:
          headers = Headers(version!);

          if (byte == CharCodes.cr) {
            state = State.headerEnding;
          } else if (byte == CharCodes.lf) {
            state = State.headerEnding;
            this.index = this.index - 1; // Make the new state see the LF again.
          } else {
            // Start of new header field.
            addWithValidation(headerField, toLowerCaseByte(byte));
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

            addWithValidation(headerField, toLowerCaseByte(byte));
          }

          break;

        case State.headerValueStart:
          if (byte == CharCodes.cr) {
            state = State.headerValueFoldOrEndCR;
          } else if (byte == CharCodes.lf) {
            state = State.headerValueFoldOrEnd;
          } else if (byte != CharCodes.sp && byte != CharCodes.ht) {
            // Start of new header value.
            addWithValidation(headerValue, byte);
            state = State.headerValue;
          }

          break;

        case State.headerValue:
          if (byte == CharCodes.cr) {
            state = State.headerValueFoldOrEndCR;
          } else if (byte == CharCodes.lf) {
            state = State.headerValueFoldOrEnd;
          } else {
            addWithValidation(headerValue, byte);
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
            const errorIfBothText =
                'Both Content-Length and Transfer-Encoding are specified, at most one is allowed';

            var headerField = String.fromCharCodes(this.headerField);
            var headerValue = String.fromCharCodes(this.headerValue);

            if (headerField == HttpHeaders.contentLengthHeader) {
              // Content Length header should not have more than one occurrence
              // or coexist with Transfer Encoding header.
              if (contentLength) {
                throw HttpException(
                    'The Content-Length header occurred more than once, at most one is allowed.');
              } else if (transferEncoding) {
                throw HttpException(errorIfBothText);
              }

              contentLength = true;
            } else if (headerField == HttpHeaders.transferEncodingHeader) {
              transferEncoding = true;

              if (caseInsensitiveCompare('chunked'.codeUnits, this.headerValue)) {
                chunked = true;
              }

              if (contentLength) {
                throw HttpException(errorIfBothText);
              }
            }

            var headers = this.headers!;

            if (headerField == HttpHeaders.connectionHeader) {
              var tokens = tokenizeFieldValue(headerValue);

              for (var i = 0; i < tokens.length; i++) {
                if (caseInsensitiveCompare('upgrade'.codeUnits, tokens[i].codeUnits)) {
                  connectionUpgrade = true;
                }

                headers.addValue(headerField, tokens[i]);
              }
            } else {
              headers.addValue(headerField, headerValue);
            }
            this.headerField.clear();
            this.headerValue.clear();

            if (byte == CharCodes.cr) {
              state = State.headerEnding;
            } else if (byte == CharCodes.lf) {
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
          expect(byte, CharCodes.lf);

          if (headersEnd()) {
            return;
          }

          break;

        case State.chunkSizeStartingCR:
          if (byte == CharCodes.lf) {
            state = State.chunkSizeStarting;
            this.index = this.index - 1; // Make the new state see the LF again.
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
            this.index = this.index - 1; // Make the new state see the LF again.
          } else if (byte == CharCodes.semiColon) {
            state = State.chunkSizeExtension;
          } else {
            var value = expectHexDigit(byte);

            // Checks whether (this.remainingContent * 16 + value) overflows.
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
            this.index = this.index - 1; // Make the new state see the LF again.
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
            this.index = this.index - 1; // Make the new state see the LF again.
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
          var remaining = buffer.length - this.index;

          if (remainingContent >= 0 && remaining > remainingContent) {
            remaining = remainingContent;
          }

          var data = Uint8List.view(buffer.buffer, buffer.offsetInBytes + this.index, remaining);
          bodyController!.add(data);

          if (remainingContent != -1) {
            remainingContent -= data.length;
          }

          this.index = this.index + data.length;

          if (remainingContent == 0) {
            if (chunked) {
              state = State.chunkSizeStartingCR;
            } else {
              reset();
              closeIncoming();
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

      if (state != State.upgaded && state != State.failure) {
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
      if (state != State.upgaded && !(state == State.body && !chunked && transferLength == -1)) {
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

    if (state == State.upgaded) {
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
      default:
        return null;
    }
  }

  bool get upgrade {
    return connectionUpgrade && state == State.upgaded;
  }

  DetachedIncoming detachIncoming() {
    // Simulate detached by marking as upgraded.
    state = State.upgaded;
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
    if (state == State.upgaded) {
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
    persistentConnection = false;
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
    return byte > 31 && byte < 128 && !Constants.separatorMap[byte];
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

  void expect(int value, int expect) {
    if (value != expect) {
      throw HttpException('Failed to parse HTTP, $value does not match $expect');
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
    this.incoming = null;

    var controller = bodyController;

    if (controller != null) {
      controller.close();
      bodyController = null;
    }

    bodyPaused = false;
    pauseStateChanged();
  }

  void pauseStateChanged() {
    if (incoming == null) {
      if (!paused && !parserCalled) {
        parse();
      }
    } else {
      if (!bodyPaused && !parserCalled) {
        parse();
      }
    }
  }

  void reportHttpError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;
    controller
      ..addError(error, stackTrace)
      ..close();
  }

  void reportBodyError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;
    bodyController
      ?..addError(error, stackTrace)
      ..close();
  }
}
