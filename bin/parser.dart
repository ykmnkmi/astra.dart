import 'dart:async' show Completer, StreamController, StreamSubscription, scheduleMicrotask;
import 'dart:io' show HttpException, HttpHeaders;
import 'dart:typed_data' show Uint8List;

class CharCode {
  static const int ht = 9;
  static const int lf = 10;
  static const int cr = 13;
  static const int sp = 32;
  // static const int ampersand = 38;
  // static const int comma = 44;
  // static const int dash = 45;
  static const int slash = 47;
  static const int zero = 48;
  static const int one = 49;
  static const int colon = 58;
  static const int semiColon = 59;
  // static const int equal = 61;
}

class Const {
  // Bytes for "HTTP".
  static const List<int> http = <int>[72, 84, 84, 80];
  // Bytes for "HTTP/1.".
  static const List<int> http1dot = <int>[72, 84, 84, 80, 47, 49, 46];
  // Bytes for "HTTP/1.0".
  // static const http10 = [72, 84, 84, 80, 47, 49, 46, 48];
  // Bytes for "HTTP/1.1".
  static const List<int> http11 = <int>[72, 84, 84, 80, 47, 49, 46, 49];

  static const bool T = true;
  static const bool F = false;

  // Loopup-map for the following characters: '()<>@,;:\\"/[]?={} \t'.
  static const List<bool> separatorMap = <bool>[
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

class HttpDetachedIncoming extends Stream<Uint8List> {
  final StreamSubscription<Uint8List>? subscription;

  final Uint8List? bufferedData;

  HttpDetachedIncoming(this.subscription, this.bufferedData);

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    var subscription = this.subscription;

    if (subscription != null) {
      subscription
        ..onData(onData)
        ..onError(onError)
        ..onDone(onDone);

      if (bufferedData == null) {
        return subscription..resume();
      }

      subscription = HttpDetachedStreamSubscription(subscription, bufferedData, onData);
      subscription.resume();
      return subscription;
    } else {
      return Stream<Uint8List>.value(bufferedData!)
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
  }
}

class HttpDetachedStreamSubscription implements StreamSubscription<Uint8List> {
  final StreamSubscription<Uint8List> subscription;

  Uint8List? injectData;

  Function? userOnData;

  bool isCanceled = false;

  bool scheduled = false;

  int pauseCount = 1;

  HttpDetachedStreamSubscription(this.subscription, this.injectData, this.userOnData);

  @override
  bool get isPaused {
    return subscription.isPaused;
  }

  @override
  Future<T> asFuture<T>([T? futureValue]) {
    return subscription.asFuture<T>(futureValue as T);
  }

  @override
  Future cancel() {
    isCanceled = true;
    injectData = null;
    return subscription.cancel();
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

      var data = injectData;
      injectData = null;
      subscription.resume();
      userOnData?.call(data);
    });
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
  void pause([Future? resumeSignal]) {
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
}

class HttpIncoming extends Stream<Uint8List> {
  final int transferLength;

  final Completer<void> comleter;

  final Stream<Uint8List> stream;

  bool fullBodyRead;

  bool upgraded;

  bool hasSubscriber;

  Map<String, String>? headers;

  String? method;

  Uri? uri;

  HttpIncoming(this.headers, this.transferLength, this.stream)
      : comleter = Completer<void>(),
        fullBodyRead = false,
        upgraded = false,
        hasSubscriber = false;

  Future<void> get dataDone {
    return comleter.future;
  }

  void close(bool closing) {
    fullBodyRead = true;
    hasSubscriber = true;
    comleter.complete(closing);
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    hasSubscriber = true;

    void errorHandler(HttpException error) {
      throw HttpException(error.message, uri: uri);
    }

    return stream
        .handleError(errorHandler)
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class HttpParser extends Stream<HttpIncoming> {
  static const int headerTotalSizeLimit = 1024 * 1024;

  static const int chunkSizeLimit = 0x7FFFFFFF;

  final StreamController<HttpIncoming> controller;

  final List<int> method = <int>[];

  final List<int> uri = <int>[];

  final List<int> headerField = <int>[];

  final List<int> headerValue = <int>[];

  bool parserCalled = false;

  Uint8List? buffer;

  int index = -1;

  State state = State.start;

  int? httpVersionIndex;

  int headersReceivedSize = 0;

  int httpVersion = HttpVersion.undetermined;

  int transferLength = -1;

  bool connectionUpgrade = false;

  bool chunked = false;

  int remainingContent = -1;

  bool contentLength = false;

  bool transferEncoding = false;

  bool connectMethod = false;

  HttpIncoming? incoming;

  StreamSubscription<Uint8List>? socketSubscription;

  bool paused = true;

  bool bodyPaused = false;

  StreamController<Uint8List>? bodyController;

  bool persistentConnection = false;

  Map<String, String>? headers;

  HttpParser() : controller = StreamController<HttpIncoming>(sync: true) {
    controller.onListen = () {
      paused = false;
    };

    controller.onPause = () {
      paused = true;
      pauseStateChanged();
    };

    controller.onResume = () {
      paused = false;
      pauseStateChanged();
    };

    controller.onCancel = () {
      socketSubscription?.cancel();
    };

    reset();
  }

  bool get upgrade {
    return connectionUpgrade && state == State.upgrade;
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

  void addWithValidation(List<int> list, int byte) {
    headersReceivedSize += 1;

    if (headersReceivedSize < headerTotalSizeLimit) {
      list.add(byte);
    } else {
      reportSizeLimitError();
    }
  }

  void closeIncoming([bool closing = false]) {
    final tmp = incoming;

    if (tmp == null) {
      return;
    }

    tmp.close(closing);
    incoming = null;

    final bodyController = this.bodyController;

    if (bodyController != null) {
      bodyController.close();
      this.bodyController = null;
    }

    bodyPaused = false;
    pauseStateChanged();
  }

  HttpIncoming createIncoming(int transferLength) {
    assert(this.incoming == null);
    assert(this.bodyController == null);
    assert(!bodyPaused);

    final bodyController = this.bodyController = StreamController<Uint8List>(sync: true);
    final incoming = this.incoming = HttpIncoming(headers!, transferLength, bodyController.stream);

    bodyController.onListen = () {
      if (incoming != this.incoming) {
        return;
      }

      assert(bodyPaused);
      bodyPaused = false;
      pauseStateChanged();
    };

    bodyController.onPause = () {
      if (incoming != this.incoming) {
        return;
      }

      assert(!bodyPaused);
      bodyPaused = true;
      pauseStateChanged();
    };

    bodyController.onResume = () {
      if (incoming != this.incoming) {
        return;
      }

      assert(bodyPaused);
      bodyPaused = false;
      pauseStateChanged();
    };

    bodyController.onCancel = () {
      if (incoming != this.incoming) {
        return;
      }

      socketSubscription?.cancel();
      closeIncoming(true);
      controller.close();
    };

    bodyPaused = true;
    pauseStateChanged();
    return incoming;
  }

  HttpDetachedIncoming detachIncoming() {
    state = State.upgrade;
    return HttpDetachedIncoming(socketSubscription, readUnparsedData());
  }

  void doParse() {
    assert(!parserCalled);

    parserCalled = true;

    if (state == State.close) {
      throw HttpException('Data on closed connection');
    }

    if (state == State.failure) {
      throw HttpException('Data on failed connection');
    }

    final buffer = this.buffer;

    while (buffer != null && index < buffer.length && state != State.failure && state != State.upgrade) {
      if ((incoming != null && bodyPaused) || (incoming == null && paused)) {
        parserCalled = false;
        return;
      }

      var index = this.index;
      var byte = buffer[index];
      this.index = index + 1;

      switch (state) {
        case State.start:
          if (byte == Const.http[0]) {
            httpVersionIndex = 1;
            state = State.methodOrResponseHTTPVersion;
          } else {
            if (!isTokenChar(byte)) {
              throw HttpException('Invalid request method');
            }

            addWithValidation(method, byte);
            state = State.requestLineMethod;
          }

          break;

        case State.methodOrResponseHTTPVersion:
          final httpVersionIndex = this.httpVersionIndex!;

          for (int i = 0; i < httpVersionIndex; i += 1) {
            addWithValidation(method, Const.http[i]);
          }

          if (byte == CharCode.sp) {
            state = State.requestLineURI;
          } else {
            addWithValidation(method, byte);
            httpVersion = HttpVersion.undetermined;
            state = State.requestLineMethod;
          }

          break;

        case State.requestLineMethod:
          if (byte == CharCode.sp) {
            state = State.requestLineURI;
          } else {
            if (Const.separatorMap[byte] || byte == CharCode.cr || byte == CharCode.lf) {
              throw HttpException('Invalid request method');
            }

            addWithValidation(method, byte);
          }

          break;

        case State.requestLineURI:
          if (byte == CharCode.sp) {
            if (uri.isEmpty) {
              throw HttpException('Invalid request, empty URI');
            }

            state = State.requestLineHTTPVersion;
            httpVersionIndex = 0;
          } else {
            if (byte == CharCode.cr || byte == CharCode.lf) {
              throw HttpException('Invalid request, unexpected $byte in URI');
            }

            addWithValidation(uri, byte);
          }

          break;

        case State.requestLineHTTPVersion:
          var httpVersionIndex = this.httpVersionIndex!;

          if (httpVersionIndex < Const.http1dot.length) {
            expect(byte, Const.http11[httpVersionIndex]);
            this.httpVersionIndex = httpVersionIndex + 1;
          } else if (this.httpVersionIndex == Const.http1dot.length) {
            if (byte == CharCode.one) {
              httpVersion = HttpVersion.http11;
              persistentConnection = true;
              this.httpVersionIndex = httpVersionIndex + 1;
            } else if (byte == CharCode.zero) {
              httpVersion = HttpVersion.http10;
              persistentConnection = false;
              this.httpVersionIndex = httpVersionIndex + 1;
            } else {
              throw HttpException('Invalid response, invalid HTTP version');
            }
          } else {
            if (byte == CharCode.cr) {
              state = State.requestLineEnding;
            } else if (byte == CharCode.lf) {
              state = State.requestLineEnding;
              this.index = this.index - 1;
            }
          }

          break;

        case State.requestLineEnding:
          expect(byte, CharCode.lf);
          state = State.headerStart;
          break;

        case State.headerStart:
          headers = <String, String>{};

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
            final headerField = String.fromCharCodes(this.headerField);
            final headerValue = String.fromCharCodes(this.headerValue);

            if (headerField == HttpHeaders.contentLengthHeader) {
              if (contentLength) {
                throw HttpException('The Content-Length header occurred more than once, at most one is allowed.');
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

            final headers = this.headers!;

            if (headerField == HttpHeaders.connectionHeader) {
              final tokens = tokenizeFieldValue(headerValue);

              for (var i = 0; i < tokens.length; i += 1) {
                final isUpgrade = caseInsensitiveCompare('upgrade'.codeUnits, tokens[i].codeUnits);

                if (isUpgrade) {
                  connectionUpgrade = true;
                }

                headers[headerField] = tokens[i];
              }
            } else {
              headers[headerField] = headerValue;
            }

            this.headerField.clear();
            this.headerValue.clear();

            if (byte == CharCode.cr) {
              state = State.headerEnding;
            } else if (byte == CharCode.lf) {
              state = State.headerEnding;
              this.index = this.index - 1;
            } else {
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
            this.index = this.index - 1;
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
            this.index = this.index - 1;
          } else if (byte == CharCode.semiColon) {
            state = State.chunkSizeExtension;
          } else {
            final value = expectHexDigit(byte);

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
            this.index = this.index - 1;
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
            this.index = this.index - 1;
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
          this.index -= 1;
          var dataAvailable = buffer.length - this.index;

          if (remainingContent >= 0 && dataAvailable > remainingContent) {
            dataAvailable = remainingContent;
          }

          final data = Uint8List.view(buffer.buffer, buffer.offsetInBytes + this.index, dataAvailable);
          bodyController!.add(data);

          if (remainingContent != -1) {
            remainingContent -= data.length;
          }

          this.index += data.length;

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
          assert(false);
          break;

        default:
          assert(false);
          break;
      }
    }

    parserCalled = false;

    if (buffer != null && index == buffer.length) {
      releaseBuffer();

      if (state != State.upgrade && state != State.failure) {
        socketSubscription!.resume();
      }
    }
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

  bool headersEnd() {
    final contentLengthHeader = headers!['content-length'];
    transferLength = contentLengthHeader == null ? 0 : int.tryParse(contentLengthHeader) ?? 0;

    if (chunked) {
      transferLength = -1;
    }

    if (transferLength < 0 && chunked == false) {
      transferLength = 0;
    }

    if (connectionUpgrade) {
      state = State.upgrade;
      transferLength = 0;
    }

    final incoming = createIncoming(transferLength);
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
    } else if (chunked) {
      state = State.chunkSize;
      remainingContent = 0;
    } else if (transferLength > 0) {
      remainingContent = transferLength;
      state = State.body;
    } else {
      state = State.body;
    }

    parserCalled = false;
    controller.add(incoming);
    return true;
  }

  @override
  StreamSubscription<HttpIncoming> listen(void Function(HttpIncoming event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void onData(Uint8List buffer) {
    assert(this.buffer == null);
    socketSubscription!.pause();
    this.buffer = buffer;
    index = 0;
    parse();
  }

  void onDone() {
    socketSubscription = null;

    if (state == State.close || state == State.failure) {
      return;
    }

    if (incoming != null) {
      if (state != State.upgrade && !(state == State.body && !chunked && transferLength == -1)) {
        reportBodyError(HttpException('Connection closed while receiving data'));
      }

      closeIncoming(true);
      controller.close();
      return;
    }

    if (state == State.start) {
      controller.close();
      return;
    }

    if (state == State.upgrade) {
      controller.close();
      return;
    }

    if (state.index < State.chunkSizeStartingCR.index) {
      state = State.failure;
      reportHttpError(HttpException('Connection closed before full header was received'));
      controller.close();
      return;
    }

    if (!chunked && transferLength == -1) {
      state = State.close;
    } else {
      state = State.failure;
      reportHttpError(HttpException('Connection closed before full body was received'));
    }

    controller.close();
  }

  void parse() {
    try {
      doParse();
    } catch (e, s) {
      if (state.index >= State.chunkSizeStartingCR.index && state.index <= State.body.index) {
        state = State.failure;
        reportBodyError(e, s);
      } else {
        state = State.failure;
        reportHttpError(e, s);
      }
    }
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

  Uint8List? readUnparsedData() {
    final buffer = this.buffer;

    if (buffer == null) {
      return null;
    }

    final index = this.index;

    if (index == buffer.length) {
      return null;
    }

    final result = buffer.sublist(index);
    releaseBuffer();
    return result;
  }

  void releaseBuffer() {
    buffer = null;
    index = -1;
  }

  void reportBodyError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;
    bodyController?.addError(error, stackTrace);
    bodyController?.close();
  }

  void reportHttpError(Object error, [StackTrace? stackTrace]) {
    socketSubscription?.cancel();
    state = State.failure;
    controller.addError(error, stackTrace);
    controller.close();
  }

  void reportSizeLimitError() {
    var method = '';

    switch (state) {
      case State.start:
      case State.methodOrResponseHTTPVersion:
      case State.requestLineMethod:
        method = 'Method';
        break;

      case State.requestLineURI:
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

  void reset() {
    if (state == State.upgrade) {
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

  void wrap(Stream<Uint8List> stream) {
    socketSubscription = stream.listen(onData, onError: controller.addError, onDone: onDone);
  }

  static bool caseInsensitiveCompare(List<int> expected, List<int> value) {
    if (expected.length != value.length) {
      return false;
    }

    for (var i = 0; i < expected.length; i += 1) {
      if (expected[i] != toLowerCaseByte(value[i])) {
        return false;
      }
    }

    return true;
  }

  static bool isTokenChar(int byte) {
    return byte > 31 && byte < 128 && !Const.separatorMap[byte];
  }

  static Future<HttpIncoming> parseStream(Stream<Uint8List> stream) async {
    final parser = HttpParser();
    parser.wrap(stream);
    final message = await parser.controller.stream.first;
    parser.controller.close();
    return message;
  }

  static List<String> tokenizeFieldValue(String headerValue) {
    final tokens = <String>[];
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
    return (((x - 0x41) & 0x7f) < 26) ? (x | 0x20) : x;
  }
}

class HttpVersion {
  static const int undetermined = 0;
  static const int http10 = 1;
  static const int http11 = 2;
}

enum State {
  start,
  methodOrResponseHTTPVersion,
  responseHTTPVersion,
  requestLineMethod,
  requestLineURI,
  requestLineHTTPVersion,
  requestLineEnding,
  headerStart,
  headerField,
  headerValueStart,
  headerValue,
  headerValueFoldOrEndCR,
  headerValueFoldOrEnd,
  headerEnding,

  chunkSizeStartingCR,
  chunkSizeStarting,
  chunkSize,
  chunkSizeExtension,
  chunkSizeEnding,
  chunkedBodyDoneCR,
  chunkedBodyDone,
  body,
  close,
  upgrade,
  failure,
}
