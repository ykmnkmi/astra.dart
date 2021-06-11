import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class _Const {
  // Bytes for "HTTP".
  static const HTTP = const [72, 84, 84, 80];
  // Bytes for "HTTP/1.".
  static const HTTP1DOT = const [72, 84, 84, 80, 47, 49, 46];
  // Bytes for "HTTP/1.0".
  static const HTTP10 = const [72, 84, 84, 80, 47, 49, 46, 48];
  // Bytes for "HTTP/1.1".
  static const HTTP11 = const [72, 84, 84, 80, 47, 49, 46, 49];

  static const bool T = true;
  static const bool F = false;
  // Loopup-map for the following characters: '()<>@,;:\\"/[]?={} \t'.
  static const SEPARATOR_MAP = const [
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
class _CharCode {
  static const int HT = 9;
  static const int LF = 10;
  static const int CR = 13;
  static const int SP = 32;
  static const int AMPERSAND = 38;
  static const int COMMA = 44;
  static const int DASH = 45;
  static const int SLASH = 47;
  static const int ZERO = 48;
  static const int ONE = 49;
  static const int COLON = 58;
  static const int SEMI_COLON = 59;
  static const int EQUAL = 61;
}

// States of the HTTP parser state machine.
class _State {
  static const int START = 0;
  static const int METHOD_OR_RESPONSE_HTTP_VERSION = 1;
  static const int RESPONSE_HTTP_VERSION = 2;
  static const int REQUEST_LINE_METHOD = 3;
  static const int REQUEST_LINE_URI = 4;
  static const int REQUEST_LINE_HTTP_VERSION = 5;
  static const int REQUEST_LINE_ENDING = 6;
  static const int RESPONSE_LINE_STATUS_CODE = 7;
  static const int RESPONSE_LINE_REASON_PHRASE = 8;
  static const int RESPONSE_LINE_ENDING = 9;
  static const int HEADER_START = 10;
  static const int HEADER_FIELD = 11;
  static const int HEADER_VALUE_START = 12;
  static const int HEADER_VALUE = 13;
  static const int HEADER_VALUE_FOLD_OR_END_CR = 14;
  static const int HEADER_VALUE_FOLD_OR_END = 15;
  static const int HEADER_ENDING = 16;

  static const int CHUNK_SIZE_STARTING_CR = 17;
  static const int CHUNK_SIZE_STARTING = 18;
  static const int CHUNK_SIZE = 19;
  static const int CHUNK_SIZE_EXTENSION = 20;
  static const int CHUNK_SIZE_ENDING = 21;
  static const int CHUNKED_BODY_DONE_CR = 22;
  static const int CHUNKED_BODY_DONE = 23;
  static const int BODY = 24;
  static const int CLOSED = 25;
  static const int UPGRADED = 26;
  static const int FAILURE = 27;

  static const int FIRST_BODY_STATE = CHUNK_SIZE_STARTING_CR;
}

// HTTP version of the request or response being parsed.
class _HttpVersion {
  static const int UNDETERMINED = 0;
  static const int HTTP10 = 1;
  static const int HTTP11 = 2;
}

// States of the HTTP parser state machine.
class _MessageType {
  static const int UNDETERMINED = 0;
  static const int REQUEST = 1;
  static const int RESPONSE = 0;
}

/**
 * The _HttpDetachedStreamSubscription takes a subscription and some extra data,
 * and makes it possible to "inject" the data in from of other data events
 * from the subscription.
 *
 * It does so by overriding pause/resume, so that once the
 * _HttpDetachedStreamSubscription is resumed, it'll deliver the data before
 * resuming the underlaying subscription.
 */
class _HttpDetachedStreamSubscription implements StreamSubscription<Uint8List> {
  final StreamSubscription<Uint8List> _subscription;
  Uint8List? _injectData;
  Function? _userOnData;
  bool _isCanceled = false;
  bool _scheduled = false;
  int _pauseCount = 1;

  _HttpDetachedStreamSubscription(this._subscription, this._injectData, this._userOnData);

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  Future<T> asFuture<T>([T? futureValue]) => _subscription.asFuture<T>(futureValue as T);

  @override
  Future cancel() {
    _isCanceled = true;
    _injectData = null;
    return _subscription.cancel();
  }

  @override
  void onData(void Function(Uint8List data)? handleData) {
    _userOnData = handleData;
    _subscription.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    _subscription.onDone(handleDone);
  }

  @override
  void onError(Function? handleError) {
    _subscription.onError(handleError);
  }

  @override
  void pause([Future? resumeSignal]) {
    if (_injectData == null) {
      _subscription.pause(resumeSignal);
    } else {
      _pauseCount++;
      if (resumeSignal != null) {
        resumeSignal.whenComplete(resume);
      }
    }
  }

  @override
  void resume() {
    if (_injectData == null) {
      _subscription.resume();
    } else {
      _pauseCount--;
      _maybeScheduleData();
    }
  }

  void _maybeScheduleData() {
    if (_scheduled) return;
    if (_pauseCount != 0) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_pauseCount > 0 || _isCanceled) return;
      var data = _injectData;
      _injectData = null;
      // To ensure that 'subscription.isPaused' is false, we resume the
      // subscription here. This is fine as potential events are delayed.
      _subscription.resume();
      _userOnData?.call(data);
    });
  }
}

class _HttpDetachedIncoming extends Stream<Uint8List> {
  final StreamSubscription<Uint8List>? subscription;
  final Uint8List? bufferedData;

  _HttpDetachedIncoming(this.subscription, this.bufferedData);

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
      return _HttpDetachedStreamSubscription(subscription, bufferedData, onData)..resume();
    } else {
      // TODO(26379): add test for this branch.
      return Stream<Uint8List>.fromIterable([bufferedData!])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
  }
}

class _HttpIncoming extends Stream<Uint8List> {
  final int _transferLength;
  final Completer<bool> _dataCompleter = Completer<bool>();
  final Stream<Uint8List> _stream;

  bool fullBodyRead = false;

  // Common properties.
  final _HttpHeaders headers;
  bool upgraded = false;

  // ClientResponse properties.
  int? statusCode;
  String? reasonPhrase;

  // Request properties.
  String? method;
  Uri? uri;

  bool hasSubscriber = false;

  // The transfer length if the length of the message body as it
  // appears in the message (RFC 2616 section 4.4). This can be -1 if
  // the length of the massage body is not known due to transfer
  // codings.
  int get transferLength => _transferLength;

  _HttpIncoming(this.headers, this._transferLength, this._stream);

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    hasSubscriber = true;
    return _stream.handleError((error) {
      throw HttpException(error.message as String, uri: uri);
    }).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  // Is completed once all data have been received.
  Future<bool> get dataDone => _dataCompleter.future;

  void close(bool closing) {
    fullBodyRead = true;
    hasSubscriber = true;
    _dataCompleter.complete(closing);
  }
}

class _HttpParser extends Stream<_HttpIncoming> {
  // State.
  bool _parserCalled = false;

  // The data that is currently being parsed.
  Uint8List? _buffer;
  int _index = -1;

  // Whether a HTTP request is being parsed (as opposed to a response).
  final bool _requestParser;
  int _state = _State.START;
  int? _httpVersionIndex;
  int _messageType = _MessageType.UNDETERMINED;
  int _statusCode = 0;
  int _statusCodeLength = 0;
  final List<int> _method = [];
  final List<int> _uriOrReasonPhrase = [];
  final List<int> _headerField = [];
  final List<int> _headerValue = [];
  static const _headerTotalSizeLimit = 1024 * 1024;
  int _headersReceivedSize = 0;

  int _httpVersion = _HttpVersion.UNDETERMINED;
  int _transferLength = -1;
  bool _persistentConnection = false;
  bool _connectionUpgrade = false;
  bool _chunked = false;

  bool _noMessageBody = false;
  int _remainingContent = -1;
  bool _contentLength = false;
  bool _transferEncoding = false;
  bool connectMethod = false;

  _HttpHeaders? _headers;

  // The limit for parsing chunk size
  final int _chunkSizeLimit = 0x7FFFFFFF;

  // The current incoming connection.
  _HttpIncoming? _incoming;
  StreamSubscription<Uint8List>? _socketSubscription;
  bool _paused = true;
  bool _bodyPaused = false;
  final StreamController<_HttpIncoming> _controller;
  StreamController<Uint8List>? _bodyController;

  factory _HttpParser.requestParser() {
    return _HttpParser._(true);
  }

  factory _HttpParser.responseParser() {
    return _HttpParser._(false);
  }

  _HttpParser._(this._requestParser) : _controller = StreamController<_HttpIncoming>(sync: true) {
    _controller
      ..onListen = () {
        _paused = false;
      }
      ..onPause = () {
        _paused = true;
        _pauseStateChanged();
      }
      ..onResume = () {
        _paused = false;
        _pauseStateChanged();
      }
      ..onCancel = () {
        _socketSubscription?.cancel();
      };
    _reset();
  }

  @override
  StreamSubscription<_HttpIncoming> listen(void Function(_HttpIncoming event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void listenToStream(Stream<Uint8List> stream) {
    // Listen to the stream and handle data accordingly. When a
    // _HttpIncoming is created, _dataPause, _dataResume, _dataDone is
    // given to provide a way of controlling the parser.
    // TODO(ajohnsen): Remove _dataPause, _dataResume and _dataDone and clean up
    // how the _HttpIncoming signals the parser.
    _socketSubscription = stream.listen(_onData, onError: _controller.addError, onDone: _onDone);
  }

  void _parse() {
    try {
      _doParse();
    } catch (e, s) {
      if (_state >= _State.CHUNK_SIZE_STARTING_CR && _state <= _State.BODY) {
        _state = _State.FAILURE;
        _reportBodyError(e, s);
      } else {
        _state = _State.FAILURE;
        _reportHttpError(e, s);
      }
    }
  }

  // Process end of headers. Returns true if the parser should stop
  // parsing and return. This will be in case of either an upgrade
  // request or a request or response with an empty body.
  bool _headersEnd() {
    var headers = _headers!;
    // If method is CONNECT, response parser should ignore any Content-Length or
    // Transfer-Encoding header fields in a successful response.
    // [RFC 7231](https://tools.ietf.org/html/rfc7231#section-4.3.6)
    if (!_requestParser && _statusCode >= 200 && _statusCode < 300 && connectMethod) {
      _transferLength = -1;
      headers.chunkedTransferEncoding = false;
      _chunked = false;
      headers.removeAll(HttpHeaders.contentLengthHeader);
      headers.removeAll(HttpHeaders.transferEncodingHeader);
    }
    headers._mutable = false;

    _transferLength = headers.contentLength;
    // Ignore the Content-Length header if Transfer-Encoding
    // is chunked (RFC 2616 section 4.4)
    if (_chunked) _transferLength = -1;

    // If a request message has neither Content-Length nor
    // Transfer-Encoding the message must not have a body (RFC
    // 2616 section 4.3).
    if (_messageType == _MessageType.REQUEST && _transferLength < 0 && _chunked == false) {
      _transferLength = 0;
    }
    if (_connectionUpgrade) {
      _state = _State.UPGRADED;
      _transferLength = 0;
    }
    var incoming = _createIncoming(_transferLength);
    if (_requestParser) {
      incoming.method = String.fromCharCodes(_method);
      incoming.uri = Uri.parse(String.fromCharCodes(_uriOrReasonPhrase));
    } else {
      incoming.statusCode = _statusCode;
      incoming.reasonPhrase = String.fromCharCodes(_uriOrReasonPhrase);
    }
    _method.clear();
    _uriOrReasonPhrase.clear();
    if (_connectionUpgrade) {
      incoming.upgraded = true;
      _parserCalled = false;
      _closeIncoming();
      _controller.add(incoming);
      return true;
    }
    if (_transferLength == 0 || (_messageType == _MessageType.RESPONSE && _noMessageBody)) {
      _reset();
      _closeIncoming();
      _controller.add(incoming);
      return false;
    } else if (_chunked) {
      _state = _State.CHUNK_SIZE;
      _remainingContent = 0;
    } else if (_transferLength > 0) {
      _remainingContent = _transferLength;
      _state = _State.BODY;
    } else {
      // Neither chunked nor content length. End of body
      // indicated by close.
      _state = _State.BODY;
    }
    _parserCalled = false;
    _controller.add(incoming);
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

  void _doParse() {
    assert(!_parserCalled);
    _parserCalled = true;
    if (_state == _State.CLOSED) {
      throw HttpException("Data on closed connection");
    }
    if (_state == _State.FAILURE) {
      throw HttpException("Data on failed connection");
    }
    while (_buffer != null && _index < _buffer!.length && _state != _State.FAILURE && _state != _State.UPGRADED) {
      // Depending on _incoming, we either break on _bodyPaused or _paused.
      if ((_incoming != null && _bodyPaused) || (_incoming == null && _paused)) {
        _parserCalled = false;
        return;
      }
      int index = _index;
      int byte = _buffer![index];
      _index = index + 1;
      switch (_state) {
        case _State.START:
          if (byte == _Const.HTTP[0]) {
            // Start parsing method or HTTP version.
            _httpVersionIndex = 1;
            _state = _State.METHOD_OR_RESPONSE_HTTP_VERSION;
          } else {
            // Start parsing method.
            if (!_isTokenChar(byte)) {
              throw HttpException("Invalid request method");
            }
            _addWithValidation(_method, byte);
            if (!_requestParser) {
              throw HttpException("Invalid response line");
            }
            _state = _State.REQUEST_LINE_METHOD;
          }
          break;

        case _State.METHOD_OR_RESPONSE_HTTP_VERSION:
          var httpVersionIndex = _httpVersionIndex!;
          if (httpVersionIndex < _Const.HTTP.length && byte == _Const.HTTP[httpVersionIndex]) {
            // Continue parsing HTTP version.
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == _Const.HTTP.length && byte == _CharCode.SLASH) {
            // HTTP/ parsed. As method is a token this cannot be a
            // method anymore.
            _httpVersionIndex = httpVersionIndex + 1;
            if (_requestParser) {
              throw HttpException("Invalid request line");
            }
            _state = _State.RESPONSE_HTTP_VERSION;
          } else {
            // Did not parse HTTP version. Expect method instead.
            for (int i = 0; i < httpVersionIndex; i++) {
              _addWithValidation(_method, _Const.HTTP[i]);
            }
            if (byte == _CharCode.SP) {
              _state = _State.REQUEST_LINE_URI;
            } else {
              _addWithValidation(_method, byte);
              _httpVersion = _HttpVersion.UNDETERMINED;
              if (!_requestParser) {
                throw HttpException("Invalid response line");
              }
              _state = _State.REQUEST_LINE_METHOD;
            }
          }
          break;

        case _State.RESPONSE_HTTP_VERSION:
          var httpVersionIndex = _httpVersionIndex!;
          if (httpVersionIndex < _Const.HTTP1DOT.length) {
            // Continue parsing HTTP version.
            _expect(byte, _Const.HTTP1DOT[httpVersionIndex]);
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == _Const.HTTP1DOT.length && byte == _CharCode.ONE) {
            // HTTP/1.1 parsed.
            _httpVersion = _HttpVersion.HTTP11;
            _persistentConnection = true;
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == _Const.HTTP1DOT.length && byte == _CharCode.ZERO) {
            // HTTP/1.0 parsed.
            _httpVersion = _HttpVersion.HTTP10;
            _persistentConnection = false;
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == _Const.HTTP1DOT.length + 1) {
            _expect(byte, _CharCode.SP);
            // HTTP version parsed.
            _state = _State.RESPONSE_LINE_STATUS_CODE;
          } else {
            throw HttpException("Invalid response line, failed to parse HTTP version");
          }
          break;

        case _State.REQUEST_LINE_METHOD:
          if (byte == _CharCode.SP) {
            _state = _State.REQUEST_LINE_URI;
          } else {
            if (_Const.SEPARATOR_MAP[byte] || byte == _CharCode.CR || byte == _CharCode.LF) {
              throw HttpException("Invalid request method");
            }
            _addWithValidation(_method, byte);
          }
          break;

        case _State.REQUEST_LINE_URI:
          if (byte == _CharCode.SP) {
            if (_uriOrReasonPhrase.isEmpty) {
              throw HttpException("Invalid request, empty URI");
            }
            _state = _State.REQUEST_LINE_HTTP_VERSION;
            _httpVersionIndex = 0;
          } else {
            if (byte == _CharCode.CR || byte == _CharCode.LF) {
              throw HttpException("Invalid request, unexpected $byte in URI");
            }
            _addWithValidation(_uriOrReasonPhrase, byte);
          }
          break;

        case _State.REQUEST_LINE_HTTP_VERSION:
          var httpVersionIndex = _httpVersionIndex!;
          if (httpVersionIndex < _Const.HTTP1DOT.length) {
            _expect(byte, _Const.HTTP11[httpVersionIndex]);
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (_httpVersionIndex == _Const.HTTP1DOT.length) {
            if (byte == _CharCode.ONE) {
              // HTTP/1.1 parsed.
              _httpVersion = _HttpVersion.HTTP11;
              _persistentConnection = true;
              _httpVersionIndex = httpVersionIndex + 1;
            } else if (byte == _CharCode.ZERO) {
              // HTTP/1.0 parsed.
              _httpVersion = _HttpVersion.HTTP10;
              _persistentConnection = false;
              _httpVersionIndex = httpVersionIndex + 1;
            } else {
              throw HttpException("Invalid response, invalid HTTP version");
            }
          } else {
            if (byte == _CharCode.CR) {
              _state = _State.REQUEST_LINE_ENDING;
            } else if (byte == _CharCode.LF) {
              _state = _State.REQUEST_LINE_ENDING;
              _index = _index - 1; // Make the new state see the LF again.
            }
          }
          break;

        case _State.REQUEST_LINE_ENDING:
          _expect(byte, _CharCode.LF);
          _messageType = _MessageType.REQUEST;
          _state = _State.HEADER_START;
          break;

        case _State.RESPONSE_LINE_STATUS_CODE:
          if (byte == _CharCode.SP) {
            _state = _State.RESPONSE_LINE_REASON_PHRASE;
          } else if (byte == _CharCode.CR) {
            // Some HTTP servers do not follow the spec and send
            // \r?\n right after the status code.
            _state = _State.RESPONSE_LINE_ENDING;
          } else if (byte == _CharCode.LF) {
            _state = _State.RESPONSE_LINE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else {
            _statusCodeLength++;
            if (byte < 0x30 || byte > 0x39) {
              throw HttpException("Invalid response status code with $byte");
            } else if (_statusCodeLength > 3) {
              throw HttpException("Invalid response, status code is over 3 digits");
            } else {
              _statusCode = _statusCode * 10 + byte - 0x30;
            }
          }
          break;

        case _State.RESPONSE_LINE_REASON_PHRASE:
          if (byte == _CharCode.CR) {
            _state = _State.RESPONSE_LINE_ENDING;
          } else if (byte == _CharCode.LF) {
            _state = _State.RESPONSE_LINE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else {
            _addWithValidation(_uriOrReasonPhrase, byte);
          }
          break;

        case _State.RESPONSE_LINE_ENDING:
          _expect(byte, _CharCode.LF);
          _messageType == _MessageType.RESPONSE;
          // Check whether this response will never have a body.
          if (_statusCode <= 199 || _statusCode == 204 || _statusCode == 304) {
            _noMessageBody = true;
          }
          _state = _State.HEADER_START;
          break;

        case _State.HEADER_START:
          _headers = _HttpHeaders(version!);
          if (byte == _CharCode.CR) {
            _state = _State.HEADER_ENDING;
          } else if (byte == _CharCode.LF) {
            _state = _State.HEADER_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else {
            // Start of new header field.
            _addWithValidation(_headerField, _toLowerCaseByte(byte));
            _state = _State.HEADER_FIELD;
          }
          break;

        case _State.HEADER_FIELD:
          if (byte == _CharCode.COLON) {
            _state = _State.HEADER_VALUE_START;
          } else {
            if (!_isTokenChar(byte)) {
              throw HttpException("Invalid header field name, with $byte");
            }
            _addWithValidation(_headerField, _toLowerCaseByte(byte));
          }
          break;

        case _State.HEADER_VALUE_START:
          if (byte == _CharCode.CR) {
            _state = _State.HEADER_VALUE_FOLD_OR_END_CR;
          } else if (byte == _CharCode.LF) {
            _state = _State.HEADER_VALUE_FOLD_OR_END;
          } else if (byte != _CharCode.SP && byte != _CharCode.HT) {
            // Start of new header value.
            _addWithValidation(_headerValue, byte);
            _state = _State.HEADER_VALUE;
          }
          break;

        case _State.HEADER_VALUE:
          if (byte == _CharCode.CR) {
            _state = _State.HEADER_VALUE_FOLD_OR_END_CR;
          } else if (byte == _CharCode.LF) {
            _state = _State.HEADER_VALUE_FOLD_OR_END;
          } else {
            _addWithValidation(_headerValue, byte);
          }
          break;

        case _State.HEADER_VALUE_FOLD_OR_END_CR:
          _expect(byte, _CharCode.LF);
          _state = _State.HEADER_VALUE_FOLD_OR_END;
          break;

        case _State.HEADER_VALUE_FOLD_OR_END:
          if (byte == _CharCode.SP || byte == _CharCode.HT) {
            _state = _State.HEADER_VALUE_START;
          } else {
            String headerField = String.fromCharCodes(_headerField);
            String headerValue = String.fromCharCodes(_headerValue);
            const errorIfBothText = "Both Content-Length and Transfer-Encoding "
                "are specified, at most one is allowed";
            if (headerField == HttpHeaders.contentLengthHeader) {
              // Content Length header should not have more than one occurance
              // or coexist with Transfer Encoding header.
              if (_contentLength) {
                throw HttpException("The Content-Length header occurred "
                    "more than once, at most one is allowed.");
              } else if (_transferEncoding) {
                throw HttpException(errorIfBothText);
              }
              _contentLength = true;
            } else if (headerField == HttpHeaders.transferEncodingHeader) {
              _transferEncoding = true;
              if (_caseInsensitiveCompare("chunked".codeUnits, _headerValue)) {
                _chunked = true;
              }
              if (_contentLength) {
                throw HttpException(errorIfBothText);
              }
            }
            var headers = _headers!;
            if (headerField == HttpHeaders.connectionHeader) {
              List<String> tokens = _tokenizeFieldValue(headerValue);
              final bool isResponse = _messageType == _MessageType.RESPONSE;
              final bool isUpgradeCode =
                  (_statusCode == HttpStatus.upgradeRequired) || (_statusCode == HttpStatus.switchingProtocols);
              for (int i = 0; i < tokens.length; i++) {
                final bool isUpgrade = _caseInsensitiveCompare("upgrade".codeUnits, tokens[i].codeUnits);
                if ((isUpgrade && !isResponse) || (isUpgrade && isResponse && isUpgradeCode)) {
                  _connectionUpgrade = true;
                }
                headers._add(headerField, tokens[i]);
              }
            } else {
              headers._add(headerField, headerValue);
            }
            _headerField.clear();
            _headerValue.clear();

            if (byte == _CharCode.CR) {
              _state = _State.HEADER_ENDING;
            } else if (byte == _CharCode.LF) {
              _state = _State.HEADER_ENDING;
              _index = _index - 1; // Make the new state see the LF again.
            } else {
              // Start of new header field.
              _state = _State.HEADER_FIELD;
              _addWithValidation(_headerField, _toLowerCaseByte(byte));
            }
          }
          break;

        case _State.HEADER_ENDING:
          _expect(byte, _CharCode.LF);
          if (_headersEnd()) {
            return;
          }
          break;

        case _State.CHUNK_SIZE_STARTING_CR:
          if (byte == _CharCode.LF) {
            _state = _State.CHUNK_SIZE_STARTING;
            _index = _index - 1; // Make the new state see the LF again.
            break;
          }
          _expect(byte, _CharCode.CR);
          _state = _State.CHUNK_SIZE_STARTING;
          break;

        case _State.CHUNK_SIZE_STARTING:
          _expect(byte, _CharCode.LF);
          _state = _State.CHUNK_SIZE;
          break;

        case _State.CHUNK_SIZE:
          if (byte == _CharCode.CR) {
            _state = _State.CHUNK_SIZE_ENDING;
          } else if (byte == _CharCode.LF) {
            _state = _State.CHUNK_SIZE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else if (byte == _CharCode.SEMI_COLON) {
            _state = _State.CHUNK_SIZE_EXTENSION;
          } else {
            int value = _expectHexDigit(byte);
            // Checks whether (_remaingingContent * 16 + value) overflows.
            if (_remainingContent > _chunkSizeLimit >> 4) {
              throw HttpException('Chunk size overflows the integer');
            }
            _remainingContent = _remainingContent * 16 + value;
          }
          break;

        case _State.CHUNK_SIZE_EXTENSION:
          if (byte == _CharCode.CR) {
            _state = _State.CHUNK_SIZE_ENDING;
          } else if (byte == _CharCode.LF) {
            _state = _State.CHUNK_SIZE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          }
          break;

        case _State.CHUNK_SIZE_ENDING:
          _expect(byte, _CharCode.LF);
          if (_remainingContent > 0) {
            _state = _State.BODY;
          } else {
            _state = _State.CHUNKED_BODY_DONE_CR;
          }
          break;

        case _State.CHUNKED_BODY_DONE_CR:
          if (byte == _CharCode.LF) {
            _state = _State.CHUNKED_BODY_DONE;
            _index = _index - 1; // Make the new state see the LF again.
            break;
          }
          _expect(byte, _CharCode.CR);
          break;

        case _State.CHUNKED_BODY_DONE:
          _expect(byte, _CharCode.LF);
          _reset();
          _closeIncoming();
          break;

        case _State.BODY:
          // The body is not handled one byte at a time but in blocks.
          _index = _index - 1;
          var buffer = _buffer!;
          int dataAvailable = buffer.length - _index;
          if (_remainingContent >= 0 && dataAvailable > _remainingContent) {
            dataAvailable = _remainingContent;
          }
          // Always present the data as a view. This way we can handle all
          // cases like this, and the user will not experience different data
          // typed (which could lead to polymorphic user code).
          Uint8List data = Uint8List.view(buffer.buffer, buffer.offsetInBytes + _index, dataAvailable);
          _bodyController!.add(data);
          if (_remainingContent != -1) {
            _remainingContent -= data.length;
          }
          _index = _index + data.length;
          if (_remainingContent == 0) {
            if (!_chunked) {
              _reset();
              _closeIncoming();
            } else {
              _state = _State.CHUNK_SIZE_STARTING_CR;
            }
          }
          break;

        case _State.FAILURE:
          // Should be unreachable.
          assert(false);
          break;

        default:
          // Should be unreachable.
          assert(false);
          break;
      }
    }

    _parserCalled = false;
    var buffer = _buffer;
    if (buffer != null && _index == buffer.length) {
      // If all data is parsed release the buffer and resume receiving
      // data.
      _releaseBuffer();
      if (_state != _State.UPGRADED && _state != _State.FAILURE) {
        _socketSubscription!.resume();
      }
    }
  }

  void _onData(Uint8List buffer) {
    _socketSubscription!.pause();
    assert(_buffer == null);
    _buffer = buffer;
    _index = 0;
    _parse();
  }

  void _onDone() {
    // onDone cancels the subscription.
    _socketSubscription = null;
    if (_state == _State.CLOSED || _state == _State.FAILURE) return;

    if (_incoming != null) {
      if (_state != _State.UPGRADED &&
          !(_state == _State.START && !_requestParser) &&
          !(_state == _State.BODY && !_chunked && _transferLength == -1)) {
        _reportBodyError(HttpException("Connection closed while receiving data"));
      }
      _closeIncoming(true);
      _controller.close();
      return;
    }
    // If the connection is idle the HTTP stream is closed.
    if (_state == _State.START) {
      if (!_requestParser) {
        _reportHttpError(HttpException("Connection closed before full header was received"));
      }
      _controller.close();
      return;
    }

    if (_state == _State.UPGRADED) {
      _controller.close();
      return;
    }

    if (_state < _State.FIRST_BODY_STATE) {
      _state = _State.FAILURE;
      // Report the error through the error callback if any. Otherwise
      // throw the error.
      _reportHttpError(HttpException("Connection closed before full header was received"));
      _controller.close();
      return;
    }

    if (!_chunked && _transferLength == -1) {
      _state = _State.CLOSED;
    } else {
      _state = _State.FAILURE;
      // Report the error through the error callback if any. Otherwise
      // throw the error.
      _reportHttpError(HttpException("Connection closed before full body was received"));
    }
    _controller.close();
  }

  String? get version {
    switch (_httpVersion) {
      case _HttpVersion.HTTP10:
        return "1.0";
      case _HttpVersion.HTTP11:
        return "1.1";
    }
    return null;
  }

  int get messageType => _messageType;
  int get transferLength => _transferLength;
  bool get upgrade => _connectionUpgrade && _state == _State.UPGRADED;
  bool get persistentConnection => _persistentConnection;

  set isHead(bool value) {
    _noMessageBody = valueOfNonNullableParamWithDefault<bool>(value, false);
  }

  _HttpDetachedIncoming detachIncoming() {
    // Simulate detached by marking as upgraded.
    _state = _State.UPGRADED;
    return _HttpDetachedIncoming(_socketSubscription, readUnparsedData());
  }

  Uint8List? readUnparsedData() {
    var buffer = _buffer;
    if (buffer == null) return null;
    var index = _index;
    if (index == buffer.length) return null;
    var result = buffer.sublist(index);
    _releaseBuffer();
    return result;
  }

  void _reset() {
    if (_state == _State.UPGRADED) return;
    _state = _State.START;
    _messageType = _MessageType.UNDETERMINED;
    _headerField.clear();
    _headerValue.clear();
    _headersReceivedSize = 0;
    _method.clear();
    _uriOrReasonPhrase.clear();

    _statusCode = 0;
    _statusCodeLength = 0;

    _httpVersion = _HttpVersion.UNDETERMINED;
    _transferLength = -1;
    _persistentConnection = false;
    _connectionUpgrade = false;
    _chunked = false;

    _noMessageBody = false;
    _remainingContent = -1;

    _contentLength = false;
    _transferEncoding = false;

    _headers = null;
  }

  void _releaseBuffer() {
    _buffer = null;
    _index = -1;
  }

  static bool _isTokenChar(int byte) {
    return byte > 31 && byte < 128 && !_Const.SEPARATOR_MAP[byte];
  }

  static bool _isValueChar(int byte) {
    return (byte > 31 && byte < 128) || (byte == _CharCode.HT);
  }

  static List<String> _tokenizeFieldValue(String headerValue) {
    List<String> tokens = <String>[];
    int start = 0;
    int index = 0;
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

  static int _toLowerCaseByte(int x) {
    // Optimized version:
    //  -  0x41 is 'A'
    //  -  0x7f is ASCII mask
    //  -  26 is the number of alpha characters.
    //  -  0x20 is the delta between lower and upper chars.
    return (((x - 0x41) & 0x7f) < 26) ? (x | 0x20) : x;
  }

  // expected should already be lowercase.
  static bool _caseInsensitiveCompare(List<int> expected, List<int> value) {
    if (expected.length != value.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != _toLowerCaseByte(value[i])) return false;
    }
    return true;
  }

  void _expect(int val1, int val2) {
    if (val1 != val2) {
      throw HttpException("Failed to parse HTTP, $val1 does not match $val2");
    }
  }

  int _expectHexDigit(int byte) {
    if (0x30 <= byte && byte <= 0x39) {
      return byte - 0x30; // 0 - 9
    } else if (0x41 <= byte && byte <= 0x46) {
      return byte - 0x41 + 10; // A - F
    } else if (0x61 <= byte && byte <= 0x66) {
      return byte - 0x61 + 10; // a - f
    } else {
      throw HttpException("Failed to parse HTTP, $byte is expected to be a Hex digit");
    }
  }

  void _addWithValidation(List<int> list, int byte) {
    _headersReceivedSize++;
    if (_headersReceivedSize < _headerTotalSizeLimit) {
      list.add(byte);
    } else {
      _reportSizeLimitError();
    }
  }

  void _reportSizeLimitError() {
    String method = "";
    switch (_state) {
      case _State.START:
      case _State.METHOD_OR_RESPONSE_HTTP_VERSION:
      case _State.REQUEST_LINE_METHOD:
        method = "Method";
        break;

      case _State.REQUEST_LINE_URI:
        method = "URI";
        break;

      case _State.RESPONSE_LINE_REASON_PHRASE:
        method = "Reason phrase";
        break;

      case _State.HEADER_START:
      case _State.HEADER_FIELD:
        method = "Header field";
        break;

      case _State.HEADER_VALUE_START:
      case _State.HEADER_VALUE:
        method = "Header value";
        break;

      default:
        throw UnsupportedError("Unexpected state: $_state");
    }

    throw HttpException("$method exceeds the $_headerTotalSizeLimit size limit");
  }

  _HttpIncoming _createIncoming(int transferLength) {
    assert(_incoming == null);
    assert(_bodyController == null);
    assert(!_bodyPaused);
    var controller = _bodyController = StreamController<Uint8List>(sync: true);
    var incoming = _incoming = _HttpIncoming(_headers!, transferLength, controller.stream);
    controller
      ..onListen = () {
        if (incoming != _incoming) return;
        assert(_bodyPaused);
        _bodyPaused = false;
        _pauseStateChanged();
      }
      ..onPause = () {
        if (incoming != _incoming) return;
        assert(!_bodyPaused);
        _bodyPaused = true;
        _pauseStateChanged();
      }
      ..onResume = () {
        if (incoming != _incoming) return;
        assert(_bodyPaused);
        _bodyPaused = false;
        _pauseStateChanged();
      }
      ..onCancel = () {
        if (incoming != _incoming) return;
        _socketSubscription?.cancel();
        _closeIncoming(true);
        _controller.close();
      };
    _bodyPaused = true;
    _pauseStateChanged();
    return incoming;
  }

  void _closeIncoming([bool closing = false]) {
    // Ignore multiple close (can happen in re-entrance).
    var tmp = _incoming;
    if (tmp == null) return;
    tmp.close(closing);
    _incoming = null;
    var controller = _bodyController;
    if (controller != null) {
      controller.close();
      _bodyController = null;
    }
    _bodyPaused = false;
    _pauseStateChanged();
  }

  void _pauseStateChanged() {
    if (_incoming != null) {
      if (!_bodyPaused && !_parserCalled) {
        _parse();
      }
    } else {
      if (!_paused && !_parserCalled) {
        _parse();
      }
    }
  }

  void _reportHttpError(Object error, [StackTrace? stackTrace]) {
    _socketSubscription?.cancel();
    _state = _State.FAILURE;
    _controller.addError(error, stackTrace);
    _controller.close();
  }

  void _reportBodyError(Object error, [StackTrace? stackTrace]) {
    _socketSubscription?.cancel();
    _state = _State.FAILURE;
    _bodyController?.addError(error, stackTrace);
    // In case of drain(), error event will close the stream.
    _bodyController?.close();
  }
}

class _HttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers;
  // The original header names keyed by the lowercase header names.
  Map<String, String>? _originalHeaderNames;
  final String protocolVersion;

  bool _mutable = true; // Are the headers currently mutable?
  List<String>? _noFoldingHeaders;

  int _contentLength = -1;
  bool _persistentConnection = true;
  bool _chunkedTransferEncoding = false;
  String? _host;
  int? _port;

  final int _defaultPortForScheme;

  _HttpHeaders(this.protocolVersion,
      {int defaultPortForScheme = HttpClient.defaultHttpPort, _HttpHeaders? initialHeaders})
      : _headers = HashMap<String, List<String>>(),
        _defaultPortForScheme = defaultPortForScheme {
    if (initialHeaders != null) {
      initialHeaders._headers.forEach((name, value) => _headers[name] = value);
      _contentLength = initialHeaders._contentLength;
      _persistentConnection = initialHeaders._persistentConnection;
      _chunkedTransferEncoding = initialHeaders._chunkedTransferEncoding;
      _host = initialHeaders._host;
      _port = initialHeaders._port;
    }
    if (protocolVersion == "1.0") {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  @override
  List<String>? operator [](String name) => _headers[_validateField(name)];

  @override
  String? value(String name) {
    name = _validateField(name);
    List<String>? values = _headers[name];
    if (values == null) return null;
    assert(values.isNotEmpty);
    if (values.length > 1) {
      throw HttpException("More than one value for header $name");
    }
    return values[0];
  }

  @override
  void add(String name, value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    String lowercaseName = _validateField(name);

    if (preserveHeaderCase && name != lowercaseName) {
      (_originalHeaderNames ??= {})[lowercaseName] = name;
    } else {
      _originalHeaderNames?.remove(lowercaseName);
    }
    _addAll(lowercaseName, value);
  }

  void _addAll(String name, Object value) {
    if (value is Iterable<Object>) {
      for (var v in value) {
        _add(name, _validateValue(v));
      }
    } else {
      _add(name, _validateValue(value));
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    String lowercaseName = _validateField(name);
    _headers.remove(lowercaseName);
    _originalHeaderNames?.remove(lowercaseName);
    if (lowercaseName == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }
    if (lowercaseName == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }
    if (preserveHeaderCase && name != lowercaseName) {
      (_originalHeaderNames ??= {})[lowercaseName] = name;
    }
    _addAll(lowercaseName, value);
  }

  @override
  void remove(String name, Object value) {
    _checkMutable();
    name = _validateField(name);
    value = _validateValue(value);
    List<String>? values = _headers[name];
    if (values != null) {
      values.remove(_valueToString(value));
      if (values.isEmpty) {
        _headers.remove(name);
        _originalHeaderNames?.remove(name);
      }
    }
    if (name == HttpHeaders.transferEncodingHeader && value == "chunked") {
      _chunkedTransferEncoding = false;
    }
  }

  @override
  void removeAll(String name) {
    _checkMutable();
    name = _validateField(name);
    _headers.remove(name);
    _originalHeaderNames?.remove(name);
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach((String name, List<String> values) {
      String originalName = _originalHeaderName(name);
      action(originalName, values);
    });
  }

  @override
  void noFolding(String name) {
    name = _validateField(name);
    (_noFoldingHeaders ??= <String>[]).add(name);
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool persistentConnection) {
    _checkMutable();
    if (persistentConnection == _persistentConnection) return;
    final originalName = _originalHeaderName(HttpHeaders.connectionHeader);
    if (persistentConnection) {
      if (protocolVersion == "1.1") {
        remove(HttpHeaders.connectionHeader, "close");
      } else {
        if (_contentLength < 0) {
          throw HttpException("Trying to set 'Connection: Keep-Alive' on HTTP 1.0 headers with "
              "no ContentLength");
        }
        add(originalName, "keep-alive", preserveHeaderCase: true);
      }
    } else {
      if (protocolVersion == "1.1") {
        add(originalName, "close", preserveHeaderCase: true);
      } else {
        remove(HttpHeaders.connectionHeader, "keep-alive");
      }
    }
    _persistentConnection = persistentConnection;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int contentLength) {
    _checkMutable();
    if (protocolVersion == "1.0" && persistentConnection && contentLength == -1) {
      throw HttpException("Trying to clear ContentLength on HTTP 1.0 headers with "
          "'Connection: Keep-Alive' set");
    }
    if (_contentLength == contentLength) return;
    _contentLength = contentLength;
    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) chunkedTransferEncoding = false;
      _set(HttpHeaders.contentLengthHeader, contentLength.toString());
    } else {
      _headers.remove(HttpHeaders.contentLengthHeader);
      if (protocolVersion == "1.1") {
        chunkedTransferEncoding = true;
      }
    }
  }

  @override
  bool get chunkedTransferEncoding => _chunkedTransferEncoding;

  @override
  set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    _checkMutable();
    if (chunkedTransferEncoding && protocolVersion == "1.0") {
      throw HttpException("Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }
    if (chunkedTransferEncoding == _chunkedTransferEncoding) return;
    if (chunkedTransferEncoding) {
      List<String>? values = _headers[HttpHeaders.transferEncodingHeader];
      if (values == null || !values.contains("chunked")) {
        // Headers does not specify chunked encoding - add it if set.
        _addValue(HttpHeaders.transferEncodingHeader, "chunked");
      }
      contentLength = -1;
    } else {
      // Headers does specify chunked encoding - remove it if not set.
      remove(HttpHeaders.transferEncodingHeader, "chunked");
    }
    _chunkedTransferEncoding = chunkedTransferEncoding;
  }

  @override
  String? get host => _host;

  @override
  set host(String? host) {
    _checkMutable();
    _host = host;
    _updateHostHeader();
  }

  @override
  int? get port => _port;

  @override
  set port(int? port) {
    _checkMutable();
    _port = port;
    _updateHostHeader();
  }

  @override
  DateTime? get ifModifiedSince {
    List<String>? values = _headers[HttpHeaders.ifModifiedSinceHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set ifModifiedSince(DateTime? ifModifiedSince) {
    _checkMutable();
    if (ifModifiedSince == null) {
      _headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  @override
  DateTime? get date {
    List<String>? values = _headers[HttpHeaders.dateHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set date(DateTime? date) {
    _checkMutable();
    if (date == null) {
      _headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(date.toUtc());
      _set(HttpHeaders.dateHeader, formatted);
    }
  }

  @override
  DateTime? get expires {
    List<String>? values = _headers[HttpHeaders.expiresHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set expires(DateTime? expires) {
    _checkMutable();
    if (expires == null) {
      _headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  @override
  ContentType? get contentType {
    var values = _headers[HttpHeaders.contentTypeHeader];
    if (values != null) {
      return ContentType.parse(values[0]);
    } else {
      return null;
    }
  }

  @override
  set contentType(ContentType? contentType) {
    _checkMutable();
    if (contentType == null) {
      _headers.remove(HttpHeaders.contentTypeHeader);
    } else {
      _set(HttpHeaders.contentTypeHeader, contentType.toString());
    }
  }

  @override
  void clear() {
    _checkMutable();
    _headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, Object value) {
    assert(name == _validateField(name));
    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          _addDate(name, value);
          return;
        }
        if (HttpHeaders.hostHeader == name) {
          _addHost(name, value);
          return;
        }
        break;
      case 7:
        if (HttpHeaders.expiresHeader == name) {
          _addExpires(name, value);
          return;
        }
        break;
      case 10:
        if (HttpHeaders.connectionHeader == name) {
          _addConnection(name, value as String);
          return;
        }
        break;
      case 12:
        if (HttpHeaders.contentTypeHeader == name) {
          _addContentType(name, value as String);
          return;
        }
        break;
      case 14:
        if (HttpHeaders.contentLengthHeader == name) {
          _addContentLength(name, value);
          return;
        }
        break;
      case 17:
        if (HttpHeaders.transferEncodingHeader == name) {
          _addTransferEncoding(name, value);
          return;
        }
        if (HttpHeaders.ifModifiedSinceHeader == name) {
          _addIfModifiedSince(name, value);
          return;
        }
    }
    _addValue(name, value);
  }

  void _addContentLength(String name, value) {
    if (value is int) {
      contentLength = value;
    } else if (value is String) {
      contentLength = int.parse(value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addTransferEncoding(String name, Object value) {
    if (value == "chunked") {
      chunkedTransferEncoding = true;
    } else {
      _addValue(HttpHeaders.transferEncodingHeader, value);
    }
  }

  void _addDate(String name, value) {
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      _set(HttpHeaders.dateHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addExpires(String name, value) {
    if (value is DateTime) {
      expires = value;
    } else if (value is String) {
      _set(HttpHeaders.expiresHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addIfModifiedSince(String name, value) {
    if (value is DateTime) {
      ifModifiedSince = value;
    } else if (value is String) {
      _set(HttpHeaders.ifModifiedSinceHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addHost(String name, value) {
    if (value is String) {
      int pos = value.indexOf(":");
      if (pos == -1) {
        _host = value;
        _port = HttpClient.defaultHttpPort;
      } else {
        if (pos > 0) {
          _host = value.substring(0, pos);
        } else {
          _host = null;
        }
        if (pos + 1 == value.length) {
          _port = HttpClient.defaultHttpPort;
        } else {
          try {
            _port = int.parse(value.substring(pos + 1));
          } on FormatException {
            _port = null;
          }
        }
      }
      _set(HttpHeaders.hostHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addConnection(String name, String value) {
    var lowerCaseValue = value.toLowerCase();
    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }
    _addValue(name, value);
  }

  void _addContentType(String name, String value) {
    _set(HttpHeaders.contentTypeHeader, value);
  }

  void _addValue(String name, Object value) {
    List<String> values = (_headers[name] ??= <String>[]);
    values.add(_valueToString(value));
  }

  String _valueToString(Object value) {
    if (value is DateTime) {
      return HttpDate.format(value);
    } else if (value is String) {
      return value; // TODO(39784): no _validateValue?
    } else {
      return _validateValue(value.toString()) as String;
    }
  }

  void _set(String name, String value) {
    assert(name == _validateField(name));
    _headers[name] = <String>[value];
  }

  void _checkMutable() {
    if (!_mutable) throw HttpException("HTTP headers are not mutable");
  }

  void _updateHostHeader() {
    var host = _host;
    if (host != null) {
      bool defaultPort = _port == null || _port == _defaultPortForScheme;
      _set("host", defaultPort ? host : "$host:$_port");
    }
  }

  bool _foldHeader(String name) {
    if (name == HttpHeaders.setCookieHeader) return false;
    var noFoldingHeaders = _noFoldingHeaders;
    return noFoldingHeaders == null || !noFoldingHeaders.contains(name);
  }

  void _finalize() {
    _mutable = false;
  }

  void _build(BytesBuilder builder, {bool skipZeroContentLength = false}) {
    // per https://tools.ietf.org/html/rfc7230#section-3.3.2
    // A user agent SHOULD NOT send a
    // Content-Length header field when the request message does not
    // contain a payload body and the method semantics do not anticipate
    // such a body.
    String? ignoreHeader = _contentLength == 0 && skipZeroContentLength ? HttpHeaders.contentLengthHeader : null;
    _headers.forEach((String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }
      String originalName = _originalHeaderName(name);
      bool fold = _foldHeader(name);
      var nameData = originalName.codeUnits;
      builder.add(nameData);
      builder.addByte(_CharCode.COLON);
      builder.addByte(_CharCode.SP);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            builder.addByte(_CharCode.COMMA);
            builder.addByte(_CharCode.SP);
          } else {
            builder.addByte(_CharCode.CR);
            builder.addByte(_CharCode.LF);
            builder.add(nameData);
            builder.addByte(_CharCode.COLON);
            builder.addByte(_CharCode.SP);
          }
        }
        builder.add(values[i].codeUnits);
      }
      builder.addByte(_CharCode.CR);
      builder.addByte(_CharCode.LF);
    });
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    _headers.forEach((String name, List<String> values) {
      String originalName = _originalHeaderName(name);
      sb..write(originalName)..write(": ");
      bool fold = _foldHeader(name);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            sb.write(", ");
          } else {
            sb..write("\n")..write(originalName)..write(": ");
          }
        }
        sb.write(values[i]);
      }
      sb.write("\n");
    });
    return sb.toString();
  }

  static String _validateField(String field) {
    for (var i = 0; i < field.length; i++) {
      if (!_HttpParser._isTokenChar(field.codeUnitAt(i))) {
        throw FormatException("Invalid HTTP header field name: ${json.encode(field)}", field, i);
      }
    }
    return field.toLowerCase();
  }

  static Object _validateValue(Object value) {
    if (value is! String) return value;
    for (var i = 0; i < value.length; i++) {
      if (!_HttpParser._isValueChar(value.codeUnitAt(i))) {
        throw FormatException("Invalid HTTP header field value: ${json.encode(value)}", value, i);
      }
    }
    return value;
  }

  String _originalHeaderName(String name) {
    return _originalHeaderNames?[name] ?? name;
  }
}

class _HeaderValue implements HeaderValue {
  String _value;
  Map<String, String?>? _parameters;
  Map<String, String?>? _unmodifiableParameters;

  _HeaderValue([this._value = "", Map<String, String?> parameters = const {}]) {
    // TODO(40614): Remove once non-nullability is sound.
    if (parameters.isNotEmpty) {
      _parameters = HashMap<String, String?>.from(parameters);
    }
  }

  static _HeaderValue parse(String value,
      {String parameterSeparator = ";", String? valueSeparator, bool preserveBackslash = false}) {
    // Parse the string.
    var result = _HeaderValue();
    result._parse(value, parameterSeparator, valueSeparator, preserveBackslash);
    return result;
  }

  @override
  String get value => _value;

  Map<String, String?> _ensureParameters() => _parameters ??= <String, String?>{};

  @override
  Map<String, String?> get parameters => _unmodifiableParameters ??= UnmodifiableMapView(_ensureParameters());

  static bool _isToken(String token) {
    if (token.isEmpty) {
      return false;
    }
    final delimiters = "\"(),/:;<=>?@[\]{}";
    for (int i = 0; i < token.length; i++) {
      int codeUnit = token.codeUnitAt(i);
      if (codeUnit <= 32 || codeUnit >= 127 || delimiters.indexOf(token[i]) >= 0) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write(_value);
    var parameters = this._parameters;
    if (parameters != null && parameters.isNotEmpty) {
      parameters.forEach((String name, String? value) {
        sb..write("; ")..write(name);
        if (value != null) {
          sb.write("=");
          if (_isToken(value)) {
            sb.write(value);
          } else {
            sb.write('"');
            int start = 0;
            for (int i = 0; i < value.length; i++) {
              // Can use codeUnitAt here instead.
              int codeUnit = value.codeUnitAt(i);
              if (codeUnit == 92 /* backslash */ || codeUnit == 34 /* double quote */) {
                sb.write(value.substring(start, i));
                sb.write(r'\');
                start = i;
              }
            }
            sb..write(value.substring(start))..write('"');
          }
        }
      });
    }
    return sb.toString();
  }

  void _parse(String s, String parameterSeparator, String? valueSeparator, bool preserveBackslash) {
    int index = 0;

    bool done() => index == s.length;

    void skipWS() {
      while (!done()) {
        if (s[index] != " " && s[index] != "\t") return;
        index++;
      }
    }

    String parseValue() {
      int start = index;
      while (!done()) {
        var char = s[index];
        if (char == " " || char == "\t" || char == valueSeparator || char == parameterSeparator) break;
        index++;
      }
      return s.substring(start, index);
    }

    void expect(String expected) {
      if (done() || s[index] != expected) {
        throw HttpException("Failed to parse header value");
      }
      index++;
    }

    bool maybeExpect(String expected) {
      if (done() || !s.startsWith(expected, index)) {
        return false;
      }
      index++;
      return true;
    }

    void parseParameters() {
      var parameters = _ensureParameters();

      String parseParameterName() {
        int start = index;
        while (!done()) {
          var char = s[index];
          if (char == " " || char == "\t" || char == "=" || char == parameterSeparator || char == valueSeparator) break;
          index++;
        }
        return s.substring(start, index).toLowerCase();
      }

      String parseParameterValue() {
        if (!done() && s[index] == "\"") {
          // Parse quoted value.
          StringBuffer sb = StringBuffer();
          index++;
          while (!done()) {
            var char = s[index];
            if (char == "\\") {
              if (index + 1 == s.length) {
                throw HttpException("Failed to parse header value");
              }
              if (preserveBackslash && s[index + 1] != "\"") {
                sb.write(char);
              }
              index++;
            } else if (char == "\"") {
              index++;
              return sb.toString();
            }
            char = s[index];
            sb.write(char);
            index++;
          }
          throw HttpException("Failed to parse header value");
        } else {
          // Parse non-quoted value.
          return parseValue();
        }
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        String name = parseParameterName();
        skipWS();
        if (maybeExpect("=")) {
          skipWS();
          String value = parseParameterValue();
          if (name == 'charset' && this is _ContentType) {
            // Charset parameter of ContentTypes are always lower-case.
            value = value.toLowerCase();
          }
          parameters[name] = value;
          skipWS();
        } else if (name.isNotEmpty) {
          parameters[name] = null;
        }
        if (done()) return;
        // TODO: Implement support for multi-valued parameters.
        if (s[index] == valueSeparator) return;
        expect(parameterSeparator);
      }
    }

    skipWS();
    _value = parseValue();
    skipWS();
    if (done()) return;
    if (s[index] == valueSeparator) return;
    maybeExpect(parameterSeparator);
    parseParameters();
  }
}

class _HttpConnection extends LinkedListEntry<_HttpConnection> with _ServiceObject {
  static const _ACTIVE = 0;
  static const _IDLE = 1;
  static const _CLOSING = 2;
  static const _DETACHED = 3;

  // Use HashMap, as we don't need to keep order.
  static final Map<int, _HttpConnection> _connections = HashMap<int, _HttpConnection>();

  final _ServerSocket _socket;
  final _HttpServer _httpServer;
  final _HttpParser _httpParser;
  int _state = _IDLE;
  StreamSubscription? _subscription;
  bool _idleMark = false;
  Future? _streamFuture;

  _HttpConnection(this._socket, this._httpServer) : _httpParser = _HttpParser.requestParser() {
    _connections[_serviceId] = this;
    _httpParser.listenToStream(_socket as Stream<Uint8List>);
    _subscription = _httpParser.listen((incoming) {
      _httpServer._markActive(this);
      // If the incoming was closed, close the connection.
      incoming.dataDone.then((closing) {
        if (closing) destroy();
      });
      // Only handle one incoming request at the time. Keep the
      // stream paused until the request has been send.
      _subscription!.pause();
      _state = _ACTIVE;
      var outgoing = _HttpOutgoing(_socket);
      var response = _HttpResponse(incoming.uri!, incoming.headers.protocolVersion, outgoing,
          _httpServer.defaultResponseHeaders, _httpServer.serverHeader);
      // Parser found badRequest and sent out Response.
      if (incoming.statusCode == HttpStatus.badRequest) {
        response.statusCode = HttpStatus.badRequest;
      }
      var request = _HttpRequest(response, incoming, _httpServer, this);
      _streamFuture = outgoing.done.then((_) {
        response.deadline = null;
        if (_state == _DETACHED) return;
        if (response.persistentConnection &&
            request.persistentConnection &&
            incoming.fullBodyRead &&
            !_httpParser.upgrade &&
            !_httpServer.closed) {
          _state = _IDLE;
          _idleMark = false;
          _httpServer._markIdle(this);
          // Resume the subscription for incoming requests as the
          // request is now processed.
          _subscription!.resume();
        } else {
          // Close socket, keep-alive not used or body sent before
          // received data was handled.
          destroy();
        }
      }, onError: (_) {
        destroy();
      });
      outgoing.ignoreBody = request.method == "HEAD";
      response._httpRequest = request;
      _httpServer._handleRequest(request);
    }, onDone: () {
      destroy();
    }, onError: (error) {
      // Ignore failed requests that was closed before headers was received.
      destroy();
    });
  }

  void markIdle() {
    _idleMark = true;
  }

  bool get isMarkedIdle => _idleMark;

  void destroy() {
    if (_state == _CLOSING || _state == _DETACHED) return;
    _state = _CLOSING;
    _socket.destroy();
    _httpServer._connectionClosed(this);
    _connections.remove(_serviceId);
  }

  Future<Socket> detachSocket() {
    _state = _DETACHED;
    // Remove connection from server.
    _httpServer._connectionClosed(this);

    _HttpDetachedIncoming detachedIncoming = _httpParser.detachIncoming();

    return _streamFuture!.then((_) {
      _connections.remove(_serviceId);
      return _DetachedSocket(_socket, detachedIncoming);
    });
  }

  HttpConnectionInfo? get connectionInfo => _HttpConnectionInfo.create(_socket);

  bool get _isActive => _state == _ACTIVE;
  bool get _isIdle => _state == _IDLE;
  bool get _isClosing => _state == _CLOSING;
  bool get _isDetached => _state == _DETACHED;

  String get _serviceTypePath => 'io/http/serverconnections';
  String get _serviceTypeName => 'HttpServerConnection';

  Map _toJSON(bool ref) {
    var name = "${_socket.address.host}:${_socket.port} <-> "
        "${_socket.remoteAddress.host}:${_socket.remotePort}";
    var r = <String, dynamic>{
      'id': _servicePath,
      'type': _serviceType(ref),
      'name': name,
      'user_name': name,
    };
    if (ref) {
      return r;
    }
    r['server'] = _httpServer._toJSON(true);
    try {
      r['socket'] = _socket._toJSON(true);
    } catch (_) {
      r['socket'] = {
        'id': _servicePath,
        'type': '@Socket',
        'name': 'UserSocket',
        'user_name': 'UserSocket',
      };
    }
    switch (_state) {
      case _ACTIVE:
        r['state'] = "Active";
        break;
      case _IDLE:
        r['state'] = "Idle";
        break;
      case _CLOSING:
        r['state'] = "Closing";
        break;
      case _DETACHED:
        r['state'] = "Detached";
        break;
      default:
        r['state'] = 'Unknown';
        break;
    }
    return r;
  }
}

int _nextServiceId = 1;

abstract class _ServiceObject {
  int __serviceId = 0;

  int get _serviceId {
    if (__serviceId == 0) __serviceId = _nextServiceId++;

    return __serviceId;
  }

  String get _servicePath => "$_serviceTypePath/$_serviceId";

  String get _serviceTypePath;

  String get _serviceTypeName;

  String _serviceType(bool ref) {
    if (ref) return "@$_serviceTypeName";
    return _serviceTypeName;
  }
}

// HTTP server waiting for socket connections.
class _HttpServer extends Stream<HttpRequest> with _ServiceObject implements HttpServer {
  // Use default Map so we keep order.
  static final Map<int, _HttpServer> _servers = <int, _HttpServer>{};

  @override
  String? serverHeader;
  @override
  final HttpHeaders defaultResponseHeaders = _initDefaultResponseHeaders();
  @override
  bool autoCompress = false;

  Duration? _idleTimeout;
  Timer? _idleTimer;

  static Future<HttpServer> bind(address, int port, int backlog, bool v6Only, bool shared) {
    return ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared)
        .then<HttpServer>((socket) {
      return _HttpServer._(socket, true);
    });
  }

  static Future<HttpServer> bindSecure(address, int port, SecurityContext? context, int backlog, bool v6Only,
      bool requestClientCertificate, bool shared) {
    return SecureServerSocket.bind(address, port, context,
            backlog: backlog, v6Only: v6Only, requestClientCertificate: requestClientCertificate, shared: shared)
        .then<HttpServer>((socket) {
      return _HttpServer._(socket, true);
    });
  }

  _HttpServer._(this._serverSocket, this._closeServer) : _controller = StreamController<HttpRequest>(sync: true) {
    _controller.onCancel = close;
    idleTimeout = const Duration(seconds: 120);
    _servers[_serviceId] = this;
  }

  _HttpServer.listenOn(this._serverSocket)
      : _closeServer = false,
        _controller = StreamController<HttpRequest>(sync: true) {
    _controller.onCancel = close;
    idleTimeout = const Duration(seconds: 120);
    _servers[_serviceId] = this;
  }

  static HttpHeaders _initDefaultResponseHeaders() {
    var defaultResponseHeaders = _HttpHeaders('1.1');
    defaultResponseHeaders.contentType = ContentType.text;
    defaultResponseHeaders.set('X-Frame-Options', 'SAMEORIGIN');
    defaultResponseHeaders.set('X-Content-Type-Options', 'nosniff');
    defaultResponseHeaders.set('X-XSS-Protection', '1; mode=block');
    return defaultResponseHeaders;
  }

  @override
  Duration? get idleTimeout => _idleTimeout;

  @override
  void set idleTimeout(Duration? duration) {
    var idleTimer = _idleTimer;
    if (idleTimer != null) {
      idleTimer.cancel();
      _idleTimer = null;
    }
    _idleTimeout = duration;
    if (duration != null) {
      _idleTimer = Timer.periodic(duration, (_) {
        for (var idle in _idleConnections.toList()) {
          if (idle.isMarkedIdle) {
            idle.destroy();
          } else {
            idle.markIdle();
          }
        }
      });
    }
  }

  @override
  StreamSubscription<HttpRequest> listen(void Function(HttpRequest event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _serverSocket.listen((Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }
      // Accept the client connection.
      _HttpConnection connection = _HttpConnection(socket, this);
      _idleConnections.add(connection);
    }, onError: (Object error, StackTrace stackTrace) {
      // Ignore HandshakeExceptions as they are bound to a single request,
      // and are not fatal for the server.
      if (error is! HandshakeException) {
        _controller.addError(error, stackTrace);
      }
    }, onDone: _controller.close);
    return _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future close({bool force = false}) {
    closed = true;
    Future result;
    if (_serverSocket != null && _closeServer) {
      result = _serverSocket.close() as Future;
    } else {
      result = Future.value();
    }
    idleTimeout = null;
    if (force) {
      for (var c in _activeConnections.toList()) {
        c.destroy();
      }
      assert(_activeConnections.isEmpty);
    }
    for (var c in _idleConnections.toList()) {
      c.destroy();
    }

    return result;
  }

  @override
  int get port {
    if (closed) throw HttpException("HttpServer is not bound to a socket");
    return _serverSocket.port as int;
  }

  @override
  InternetAddress get address {
    if (closed) throw HttpException("HttpServer is not bound to a socket");
    return _serverSocket.address as InternetAddress;
  }

  void _handleRequest(_HttpRequest request) {
    if (!closed) {
      _controller.add(request);
    } else {
      request._httpConnection.destroy();
    }
  }

  void _connectionClosed(_HttpConnection connection) {
    // Remove itself from either idle or active connections.
    connection.unlink();
  }

  void _markIdle(_HttpConnection connection) {
    _activeConnections.remove(connection);
    _idleConnections.add(connection);
  }

  void _markActive(_HttpConnection connection) {
    _idleConnections.remove(connection);
    _activeConnections.add(connection);
  }

  @override
  HttpConnectionsInfo connectionsInfo() {
    HttpConnectionsInfo result = HttpConnectionsInfo();
    result.total = _activeConnections.length + _idleConnections.length;
    _activeConnections.forEach((_HttpConnection conn) {
      if (conn._isActive) {
        result.active++;
      } else {
        assert(conn._isClosing);
        result.closing++;
      }
    });
    _idleConnections.forEach((_HttpConnection conn) {
      result.idle++;
      assert(conn._isIdle);
    });
    return result;
  }

  String get _serviceTypePath => 'io/http/servers';
  String get _serviceTypeName => 'HttpServer';

  Map<String, dynamic> _toJSON(bool ref) {
    var r = <String, dynamic>{
      'id': _servicePath,
      'type': _serviceType(ref),
      'name': '${address.host}:$port',
      'user_name': '${address.host}:$port',
    };
    if (ref) {
      return r;
    }
    try {
      r['socket'] = _serverSocket._toJSON(true);
    } catch (_) {
      r['socket'] = {
        'id': _servicePath,
        'type': '@Socket',
        'name': 'UserSocket',
        'user_name': 'UserSocket',
      };
    }
    r['port'] = port;
    r['address'] = address.host;
    r['active'] = _activeConnections.map((c) => c._toJSON(true)).toList();
    r['idle'] = _idleConnections.map((c) => c._toJSON(true)).toList();
    r['closed'] = closed;
    return r;
  }

  // Indicated if the http server has been closed.
  bool closed = false;

  // The server listen socket. Untyped as it can be both ServerSocket and
  // SecureServerSocket.
  final dynamic /*ServerSocket|SecureServerSocket*/ _serverSocket;
  final bool _closeServer;

  // Set of currently connected clients.
  final LinkedList<_HttpConnection> _activeConnections = LinkedList<_HttpConnection>();
  final LinkedList<_HttpConnection> _idleConnections = LinkedList<_HttpConnection>();
  final StreamController<HttpRequest> _controller;
}
