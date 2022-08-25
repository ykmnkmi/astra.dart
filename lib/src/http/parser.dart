// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' show HttpException, HttpHeaders, HttpStatus;
import 'dart:typed_data' show Uint8List;

import 'package:astra/src/http/headers.dart';
import 'package:astra/src/http/impl.dart';

typedef OnData = void Function(Uint8List data);

// Global constants.
class Const {
  // Bytes for "HTTP".
  static const List<int> http = <int>[72, 84, 84, 80];
  // Bytes for "HTTP/1.".
  static const List<int> http1dot = <int>[72, 84, 84, 80, 47, 49, 46];
  // Bytes for "HTTP/1.0".
  static const List<int> http10 = <int>[72, 84, 84, 80, 47, 49, 46, 48];
  // Bytes for "HTTP/1.1".
  static const List<int> http11 = <int>[72, 84, 84, 80, 47, 49, 46, 49];

  static const bool t = true, f = false;
  // Loopup-map for the following characters: '()<>@,;:\\"/[]?={} \t'.
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

// Frequently used character codes.
class CharCode {
  static const int ht = 9, lf = 10, cr = 13, sp = 32;
  static const int comma = 44, slash = 47;
  static const int zero = 48, one = 49;
  static const int colon = 58, semiColon = 59;
}

// States of the HTTP parser state machine.
class State {
  static const int start = 0;
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
class HttpVersion {
  static const int undetermined = 0;
  static const int http10 = 1;
  static const int http11 = 2;
}

// States of the HTTP parser state machine.
class MessageType {
  static const int undetermined = 0;
  static const int request = 1;
  static const int response = 0;
}

/// The _HttpDetachedStreamSubscription takes a subscription and some extra data,
/// and makes it possible to "inject" the data in from of other data events
/// from the subscription.
///
/// It does so by overriding pause/resume, so that once the
/// _HttpDetachedStreamSubscription is resumed, it'll deliver the data before
/// resuming the underlying subscription.
class DetachedStreamSubscription implements StreamSubscription<Uint8List> {
  DetachedStreamSubscription(this.subscription, this.injectData, this.userOnData);

  final StreamSubscription<Uint8List> subscription;

  Uint8List? injectData;

  OnData? userOnData;

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

  @override
  Future<void> cancel() {
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

    void callback() {
      scheduled = false;

      if (pauseCount > 0 || isCanceled) {
        return;
      }

      Uint8List data = injectData!;
      injectData = null;

      // To ensure that 'subscription.isPaused' is false, we resume the
      // subscription here. This is fine as potential events are delayed.
      subscription.resume();

      OnData? userOnData = this.userOnData;

      if (userOnData != null) {
        userOnData(data);
      }
    }

    scheduleMicrotask(callback);
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
    StreamSubscription<Uint8List>? subscription = this.subscription;

    if (subscription != null) {
      subscription
        ..onData(onData)
        ..onError(onError)
        ..onDone(onDone);

      if (bufferedData == null) {
        subscription.resume();
        return subscription;
      }

      DetachedStreamSubscription detached = DetachedStreamSubscription(subscription, bufferedData, onData);
      detached.resume();
      return detached;
    }

    // TODO(26379): add test for this branch.
    return Stream<Uint8List>.value(bufferedData!).listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }
}

/// HTTP parser which parses the data stream given to [consume].
///
/// If an HTTP parser error occurs, the parser will signal an error to either
/// the current Incoming or the _parser itself.
///
/// The connection upgrades (e.g. switching from HTTP/1.1 to the
/// WebSocket protocol) is handled in a special way. If connection
/// upgrade is specified in the headers, then on the callback to
/// [:responseStart:] the [:upgrade:] property on the [:HttpParser:]
/// object will be [:true:] indicating that from now on the protocol is
/// not HTTP anymore and no more callbacks will happen, that is
/// [:dataReceived:] and [:dataEnd:] are not called in this case as
/// there is no more HTTP data. After the upgrade the method
/// [:readUnparsedData:] can be used to read any remaining bytes in the
/// HTTP parser which are part of the protocol the connection is
/// upgrading to. These bytes cannot be processed by the HTTP parser
/// and should be handled according to whatever protocol is being
/// upgraded to.
class Parser extends Stream<Incoming> {
  // State.
  bool _parserCalled = false;

  // The data that is currently being parsed.
  Uint8List? _buffer;
  int _index = -1;

  // Whether a HTTP request is being parsed (as opposed to a response).
  final bool _requestParser;
  int _state = State.start;
  int? _httpVersionIndex;
  int _messageType = MessageType.undetermined;
  int _statusCode = 0;
  int _statusCodeLength = 0;
  final List<int> _method = [];
  final List<int> _uriOrReasonPhrase = [];
  final List<int> _headerField = [];
  final List<int> _headerValue = [];
  static const _headerTotalSizeLimit = 1024 * 1024;
  int _headersReceivedSize = 0;

  int _httpVersion = HttpVersion.undetermined;
  int _transferLength = -1;
  bool _persistentConnection = false;
  bool _connectionUpgrade = false;
  bool _chunked = false;

  bool _noMessageBody = false;
  int _remainingContent = -1;
  bool _contentLength = false;
  bool _transferEncoding = false;
  bool connectMethod = false;

  NativeHeaders? _headers;

  // The limit for parsing chunk size
  static const _chunkSizeLimit = 0x7FFFFFFF;

  // The current incoming connection.
  Incoming? _incoming;
  StreamSubscription<Uint8List>? _socketSubscription;
  bool _paused = true;
  bool _bodyPaused = false;
  final StreamController<Incoming> _controller;
  StreamController<Uint8List>? _bodyController;

  factory Parser.requestParser() {
    return Parser._(true);
  }

  factory Parser.responseParser() {
    return Parser._(false);
  }

  Parser._(this._requestParser) : _controller = StreamController<Incoming>(sync: true) {
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
  StreamSubscription<Incoming> listen(void Function(Incoming event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void listenToStream(Stream<Uint8List> stream) {
    // Listen to the stream and handle data accordingly. When a
    // Incoming is created, _dataPause, _dataResume, _dataDone is
    // given to provide a way of controlling the parser.
    // TODO(ajohnsen): Remove _dataPause, _dataResume and _dataDone and clean up
    // how the Incoming signals the parser.
    _socketSubscription = stream.listen(_onData, onError: _controller.addError, onDone: _onDone);
  }

  void _parse() {
    try {
      _doParse();
    } catch (e, s) {
      if (_state >= State.CHUNK_SIZE_STARTING_CR && _state <= State.BODY) {
        _state = State.FAILURE;
        _reportBodyError(e, s);
      } else {
        _state = State.FAILURE;
        _reportHttpError(e, s);
      }
    }
  }

  // Process end of headers. Returns true if the parser should stop
  // parsing and return. This will be in case of either an upgrade
  // request or a request or response with an empty body.
  bool headersEnd() {
    NativeHeaders headers = _headers!;

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

    _transferLength = headers.contentLength;
    // Ignore the Content-Length header if Transfer-Encoding
    // is chunked (RFC 2616 section 4.4)
    if (_chunked) _transferLength = -1;

    // If a request message has neither Content-Length nor
    // Transfer-Encoding the message must not have a body (RFC
    // 2616 section 4.3).
    if (_messageType == MessageType.request && _transferLength < 0 && _chunked == false) {
      _transferLength = 0;
    }
    if (_connectionUpgrade) {
      _state = State.UPGRADED;
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
    if (_transferLength == 0 || (_messageType == MessageType.response && _noMessageBody)) {
      _reset();
      _closeIncoming();
      _controller.add(incoming);
      return false;
    } else if (_chunked) {
      _state = State.CHUNK_SIZE;
      _remainingContent = 0;
    } else if (_transferLength > 0) {
      _remainingContent = _transferLength;
      _state = State.BODY;
    } else {
      // Neither chunked nor content length. End of body
      // indicated by close.
      _state = State.BODY;
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
    if (_state == State.CLOSED) {
      throw HttpException('Data on closed connection');
    }
    if (_state == State.FAILURE) {
      throw HttpException('Data on failed connection');
    }
    while (_buffer != null && _index < _buffer!.length && _state != State.FAILURE && _state != State.UPGRADED) {
      // Depending on _incoming, we either break on _bodyPaused or _paused.
      if ((_incoming != null && _bodyPaused) || (_incoming == null && _paused)) {
        _parserCalled = false;
        return;
      }
      int index = _index;
      int byte = _buffer![index];
      _index = index + 1;
      switch (_state) {
        case State.start:
          if (byte == Const.http[0]) {
            // Start parsing method or HTTP version.
            _httpVersionIndex = 1;
            _state = State.METHOD_OR_RESPONSE_HTTP_VERSION;
          } else {
            // Start parsing method.
            if (!isTokenChar(byte)) {
              throw HttpException('Invalid request method');
            }
            _addWithValidation(_method, byte);
            if (!_requestParser) {
              throw HttpException('Invalid response line');
            }
            _state = State.REQUEST_LINE_METHOD;
          }
          break;

        case State.METHOD_OR_RESPONSE_HTTP_VERSION:
          var httpVersionIndex = _httpVersionIndex!;
          if (httpVersionIndex < Const.http.length && byte == Const.http[httpVersionIndex]) {
            // Continue parsing HTTP version.
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == Const.http.length && byte == CharCode.slash) {
            // HTTP/ parsed. As method is a token this cannot be a
            // method anymore.
            _httpVersionIndex = httpVersionIndex + 1;
            if (_requestParser) {
              throw HttpException('Invalid request line');
            }
            _state = State.RESPONSE_HTTP_VERSION;
          } else {
            // Did not parse HTTP version. Expect method instead.
            for (int i = 0; i < httpVersionIndex; i++) {
              _addWithValidation(_method, Const.http[i]);
            }
            if (byte == CharCode.sp) {
              _state = State.REQUEST_LINE_URI;
            } else {
              _addWithValidation(_method, byte);
              _httpVersion = HttpVersion.undetermined;
              if (!_requestParser) {
                throw HttpException('Invalid response line');
              }
              _state = State.REQUEST_LINE_METHOD;
            }
          }
          break;

        case State.RESPONSE_HTTP_VERSION:
          var httpVersionIndex = _httpVersionIndex!;
          if (httpVersionIndex < Const.http1dot.length) {
            // Continue parsing HTTP version.
            _expect(byte, Const.http1dot[httpVersionIndex]);
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == Const.http1dot.length && byte == CharCode.one) {
            // HTTP/1.1 parsed.
            _httpVersion = HttpVersion.http11;
            _persistentConnection = true;
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == Const.http1dot.length && byte == CharCode.zero) {
            // HTTP/1.0 parsed.
            _httpVersion = HttpVersion.http10;
            _persistentConnection = false;
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (httpVersionIndex == Const.http1dot.length + 1) {
            _expect(byte, CharCode.sp);
            // HTTP version parsed.
            _state = State.RESPONSE_LINE_STATUS_CODE;
          } else {
            throw HttpException('Invalid response line, failed to parse HTTP version');
          }
          break;

        case State.REQUEST_LINE_METHOD:
          if (byte == CharCode.sp) {
            _state = State.REQUEST_LINE_URI;
          } else {
            if (Const.separatorMap[byte] || byte == CharCode.cr || byte == CharCode.lf) {
              throw HttpException('Invalid request method');
            }
            _addWithValidation(_method, byte);
          }
          break;

        case State.REQUEST_LINE_URI:
          if (byte == CharCode.sp) {
            if (_uriOrReasonPhrase.isEmpty) {
              throw HttpException('Invalid request, empty URI');
            }
            _state = State.REQUEST_LINE_HTTP_VERSION;
            _httpVersionIndex = 0;
          } else {
            if (byte == CharCode.cr || byte == CharCode.lf) {
              throw HttpException('Invalid request, unexpected $byte in URI');
            }
            _addWithValidation(_uriOrReasonPhrase, byte);
          }
          break;

        case State.REQUEST_LINE_HTTP_VERSION:
          var httpVersionIndex = _httpVersionIndex!;
          if (httpVersionIndex < Const.http1dot.length) {
            _expect(byte, Const.http11[httpVersionIndex]);
            _httpVersionIndex = httpVersionIndex + 1;
          } else if (_httpVersionIndex == Const.http1dot.length) {
            if (byte == CharCode.one) {
              // HTTP/1.1 parsed.
              _httpVersion = HttpVersion.http11;
              _persistentConnection = true;
              _httpVersionIndex = httpVersionIndex + 1;
            } else if (byte == CharCode.zero) {
              // HTTP/1.0 parsed.
              _httpVersion = HttpVersion.http10;
              _persistentConnection = false;
              _httpVersionIndex = httpVersionIndex + 1;
            } else {
              throw HttpException('Invalid response, invalid HTTP version');
            }
          } else {
            if (byte == CharCode.cr) {
              _state = State.REQUEST_LINE_ENDING;
            } else if (byte == CharCode.lf) {
              _state = State.REQUEST_LINE_ENDING;
              _index = _index - 1; // Make the new state see the LF again.
            }
          }
          break;

        case State.REQUEST_LINE_ENDING:
          _expect(byte, CharCode.lf);
          _messageType = MessageType.request;
          _state = State.HEADER_START;
          break;

        case State.RESPONSE_LINE_STATUS_CODE:
          if (byte == CharCode.sp) {
            _state = State.RESPONSE_LINE_REASON_PHRASE;
          } else if (byte == CharCode.cr) {
            // Some HTTP servers do not follow the spec and send
            // \r?\n right after the status code.
            _state = State.RESPONSE_LINE_ENDING;
          } else if (byte == CharCode.lf) {
            _state = State.RESPONSE_LINE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else {
            _statusCodeLength += 1;
            if (byte < 0x30 || byte > 0x39) {
              throw HttpException('Invalid response status code with $byte');
            } else if (_statusCodeLength > 3) {
              throw HttpException('Invalid response, status code is over 3 digits');
            } else {
              _statusCode = _statusCode * 10 + byte - 0x30;
            }
          }
          break;

        case State.RESPONSE_LINE_REASON_PHRASE:
          if (byte == CharCode.cr) {
            _state = State.RESPONSE_LINE_ENDING;
          } else if (byte == CharCode.lf) {
            _state = State.RESPONSE_LINE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else {
            _addWithValidation(_uriOrReasonPhrase, byte);
          }
          break;

        case State.RESPONSE_LINE_ENDING:
          _expect(byte, CharCode.lf);
          _messageType == MessageType.response;
          // Check whether this response will never have a body.
          if (_statusCode <= 199 || _statusCode == 204 || _statusCode == 304) {
            _noMessageBody = true;
          }
          _state = State.HEADER_START;
          break;

        case State.HEADER_START:
          _headers = NativeHeaders(version!);
          if (byte == CharCode.cr) {
            _state = State.HEADER_ENDING;
          } else if (byte == CharCode.lf) {
            _state = State.HEADER_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else {
            // Start of new header field.
            _addWithValidation(_headerField, _toLowerCaseByte(byte));
            _state = State.HEADER_FIELD;
          }
          break;

        case State.HEADER_FIELD:
          if (byte == CharCode.colon) {
            _state = State.HEADER_VALUE_START;
          } else {
            if (!isTokenChar(byte)) {
              throw HttpException('Invalid header field name, with $byte');
            }
            _addWithValidation(_headerField, _toLowerCaseByte(byte));
          }
          break;

        case State.HEADER_VALUE_START:
          if (byte == CharCode.cr) {
            _state = State.HEADER_VALUE_FOLD_OR_END_CR;
          } else if (byte == CharCode.lf) {
            _state = State.HEADER_VALUE_FOLD_OR_END;
          } else if (byte != CharCode.sp && byte != CharCode.ht) {
            // Start of new header value.
            _addWithValidation(_headerValue, byte);
            _state = State.HEADER_VALUE;
          }
          break;

        case State.HEADER_VALUE:
          if (byte == CharCode.cr) {
            _state = State.HEADER_VALUE_FOLD_OR_END_CR;
          } else if (byte == CharCode.lf) {
            _state = State.HEADER_VALUE_FOLD_OR_END;
          } else {
            _addWithValidation(_headerValue, byte);
          }
          break;

        case State.HEADER_VALUE_FOLD_OR_END_CR:
          _expect(byte, CharCode.lf);
          _state = State.HEADER_VALUE_FOLD_OR_END;
          break;

        case State.HEADER_VALUE_FOLD_OR_END:
          if (byte == CharCode.sp || byte == CharCode.ht) {
            _state = State.HEADER_VALUE_START;
          } else {
            String headerField = String.fromCharCodes(_headerField);
            String headerValue = String.fromCharCodes(_headerValue);
            const errorIfBothText = 'Both Content-Length and Transfer-Encoding '
                'are specified, at most one is allowed';
            if (headerField == HttpHeaders.contentLengthHeader) {
              // Content Length header should not have more than one occurrence
              // or coexist with Transfer Encoding header.
              if (_contentLength) {
                throw HttpException('The Content-Length header occurred '
                    'more than once, at most one is allowed.');
              } else if (_transferEncoding) {
                throw HttpException(errorIfBothText);
              }
              _contentLength = true;
            } else if (headerField == HttpHeaders.transferEncodingHeader) {
              _transferEncoding = true;
              if (_caseInsensitiveCompare('chunked'.codeUnits, _headerValue)) {
                _chunked = true;
              }
              if (_contentLength) {
                throw HttpException(errorIfBothText);
              }
            }
            var headers = _headers!;
            if (headerField == HttpHeaders.connectionHeader) {
              List<String> tokens = _tokenizeFieldValue(headerValue);
              final bool isResponse = _messageType == MessageType.response;
              final bool isUpgradeCode =
                  (_statusCode == HttpStatus.upgradeRequired) || (_statusCode == HttpStatus.switchingProtocols);
              for (int i = 0; i < tokens.length; i++) {
                final bool isUpgrade = _caseInsensitiveCompare('upgrade'.codeUnits, tokens[i].codeUnits);
                if ((isUpgrade && !isResponse) || (isUpgrade && isResponse && isUpgradeCode)) {
                  _connectionUpgrade = true;
                }
                headers.add(headerField, tokens[i]);
              }
            } else {
              headers.add(headerField, headerValue);
            }

            _headerField.clear();
            _headerValue.clear();

            if (byte == CharCode.cr) {
              _state = State.HEADER_ENDING;
            } else if (byte == CharCode.lf) {
              _state = State.HEADER_ENDING;
              _index = _index - 1; // Make the new state see the LF again.
            } else {
              // Start of new header field.
              _state = State.HEADER_FIELD;
              _addWithValidation(_headerField, _toLowerCaseByte(byte));
            }
          }
          break;

        case State.HEADER_ENDING:
          _expect(byte, CharCode.lf);
          if (headersEnd()) {
            return;
          }
          break;

        case State.CHUNK_SIZE_STARTING_CR:
          if (byte == CharCode.lf) {
            _state = State.CHUNK_SIZE_STARTING;
            _index = _index - 1; // Make the new state see the LF again.
            break;
          }
          _expect(byte, CharCode.cr);
          _state = State.CHUNK_SIZE_STARTING;
          break;

        case State.CHUNK_SIZE_STARTING:
          _expect(byte, CharCode.lf);
          _state = State.CHUNK_SIZE;
          break;

        case State.CHUNK_SIZE:
          if (byte == CharCode.cr) {
            _state = State.CHUNK_SIZE_ENDING;
          } else if (byte == CharCode.lf) {
            _state = State.CHUNK_SIZE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          } else if (byte == CharCode.semiColon) {
            _state = State.CHUNK_SIZE_EXTENSION;
          } else {
            int value = _expectHexDigit(byte);
            // Checks whether (_remainingContent * 16 + value) overflows.
            if (_remainingContent > _chunkSizeLimit >> 4) {
              throw HttpException('Chunk size overflows the integer');
            }
            _remainingContent = _remainingContent * 16 + value;
          }
          break;

        case State.CHUNK_SIZE_EXTENSION:
          if (byte == CharCode.cr) {
            _state = State.CHUNK_SIZE_ENDING;
          } else if (byte == CharCode.lf) {
            _state = State.CHUNK_SIZE_ENDING;
            _index = _index - 1; // Make the new state see the LF again.
          }
          break;

        case State.CHUNK_SIZE_ENDING:
          _expect(byte, CharCode.lf);
          if (_remainingContent > 0) {
            _state = State.BODY;
          } else {
            _state = State.CHUNKED_BODY_DONE_CR;
          }
          break;

        case State.CHUNKED_BODY_DONE_CR:
          if (byte == CharCode.lf) {
            _state = State.CHUNKED_BODY_DONE;
            _index = _index - 1; // Make the new state see the LF again.
            break;
          }
          _expect(byte, CharCode.cr);
          break;

        case State.CHUNKED_BODY_DONE:
          _expect(byte, CharCode.lf);
          _reset();
          _closeIncoming();
          break;

        case State.BODY:
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
              _state = State.CHUNK_SIZE_STARTING_CR;
            }
          }
          break;

        case State.FAILURE:
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
      if (_state != State.UPGRADED && _state != State.FAILURE) {
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
    if (_state == State.CLOSED || _state == State.FAILURE) return;

    if (_incoming != null) {
      if (_state != State.UPGRADED &&
          !(_state == State.start && !_requestParser) &&
          !(_state == State.BODY && !_chunked && _transferLength == -1)) {
        _reportBodyError(HttpException('Connection closed while receiving data'));
      }
      _closeIncoming(true);
      _controller.close();
      return;
    }
    // If the connection is idle the HTTP stream is closed.
    if (_state == State.start) {
      if (!_requestParser) {
        _reportHttpError(HttpException('Connection closed before full header was received'));
      }
      _controller.close();
      return;
    }

    if (_state == State.UPGRADED) {
      _controller.close();
      return;
    }

    if (_state < State.FIRST_BODY_STATE) {
      _state = State.FAILURE;
      // Report the error through the error callback if any. Otherwise
      // throw the error.
      _reportHttpError(HttpException('Connection closed before full header was received'));
      _controller.close();
      return;
    }

    if (!_chunked && _transferLength == -1) {
      _state = State.CLOSED;
    } else {
      _state = State.FAILURE;
      // Report the error through the error callback if any. Otherwise
      // throw the error.
      _reportHttpError(HttpException('Connection closed before full body was received'));
    }
    _controller.close();
  }

  String? get version {
    switch (_httpVersion) {
      case HttpVersion.http10:
        return '1.0';
      case HttpVersion.http11:
        return '1.1';
    }
    return null;
  }

  int get messageType => _messageType;
  int get transferLength => _transferLength;
  bool get upgrade => _connectionUpgrade && _state == State.UPGRADED;
  bool get persistentConnection => _persistentConnection;

  set isHead(bool value) {
    _noMessageBody = value;
  }

  DetachedIncoming detachIncoming() {
    // Simulate detached by marking as upgraded.
    _state = State.UPGRADED;
    return DetachedIncoming(_socketSubscription, readUnparsedData());
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
    if (_state == State.UPGRADED) return;
    _state = State.start;
    _messageType = MessageType.undetermined;
    _headerField.clear();
    _headerValue.clear();
    _headersReceivedSize = 0;
    _method.clear();
    _uriOrReasonPhrase.clear();

    _statusCode = 0;
    _statusCodeLength = 0;

    _httpVersion = HttpVersion.undetermined;
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

  static bool isTokenChar(int byte) {
    return byte > 31 && byte < 128 && !Const.separatorMap[byte];
  }

  static bool isValueChar(int byte) {
    return (byte > 31 && byte < 128) || (byte == CharCode.ht);
  }

  static List<String> _tokenizeFieldValue(String headerValue) {
    List<String> tokens = <String>[];
    int start = 0;
    int index = 0;
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
      throw HttpException('Failed to parse HTTP, $val1 does not match $val2');
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
      throw HttpException('Failed to parse HTTP, $byte is expected to be a Hex digit');
    }
  }

  void _addWithValidation(List<int> list, int byte) {
    _headersReceivedSize += 1;
    if (_headersReceivedSize < _headerTotalSizeLimit) {
      list.add(byte);
    } else {
      _reportSizeLimitError();
    }
  }

  void _reportSizeLimitError() {
    String method = '';
    switch (_state) {
      case State.start:
      case State.METHOD_OR_RESPONSE_HTTP_VERSION:
      case State.REQUEST_LINE_METHOD:
        method = 'Method';
        break;

      case State.REQUEST_LINE_URI:
        method = 'URI';
        break;

      case State.RESPONSE_LINE_REASON_PHRASE:
        method = 'Reason phrase';
        break;

      case State.HEADER_START:
      case State.HEADER_FIELD:
        method = 'Header field';
        break;

      case State.HEADER_VALUE_START:
      case State.HEADER_VALUE:
        method = 'Header value';
        break;

      default:
        throw UnsupportedError('Unexpected state: $_state');
    }
    throw HttpException('$method exceeds the $_headerTotalSizeLimit size limit');
  }

  Incoming _createIncoming(int transferLength) {
    assert(_incoming == null);
    assert(_bodyController == null);
    assert(!_bodyPaused);
    var controller = _bodyController = StreamController<Uint8List>(sync: true);
    var incoming = _incoming = Incoming(_headers!, transferLength, controller.stream);
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
    _state = State.FAILURE;
    _controller.addError(error, stackTrace);
    _controller.close();
  }

  void _reportBodyError(Object error, [StackTrace? stackTrace]) {
    _socketSubscription?.cancel();
    _state = State.FAILURE;
    _bodyController?.addError(error, stackTrace);
    // In case of drain(), error event will close the stream.
    _bodyController?.close();
  }
}
