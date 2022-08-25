// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection' show HashMap, LinkedList, LinkedListEntry;
import 'dart:convert' show ByteConversionSink, Encoding, latin1;
import 'dart:io'
    show
        ContentType,
        Cookie,
        HandshakeException,
        HttpClient,
        HttpConnectionInfo,
        HttpConnectionsInfo,
        HttpException,
        HttpHeaders,
        HttpStatus,
        IOSink,
        InternetAddress,
        InternetAddressType,
        RawSocketOption,
        SecureServerSocket,
        SecureSocket,
        SecurityContext,
        ServerSocket,
        Socket,
        SocketException,
        SocketOption,
        TlsException,
        X509Certificate,
        ZLibEncoder;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:astra/src/http/headers.dart';
import 'package:astra/src/http/parser.dart';

int _nextServiceId = 1;

// TODO(ajohnsen): Use other way of getting a unique id.
abstract class _ServiceObject {
  int __serviceId = 0;

  int get _serviceId {
    if (__serviceId == 0) __serviceId = _nextServiceId++;
    return __serviceId;
  }
}

class _CopyingBytesBuilder implements BytesBuilder {
  // Start with 1024 bytes.
  static const int _INIT_SIZE = 1024;

  static final _emptyList = Uint8List(0);

  int _length = 0;
  Uint8List _buffer;

  _CopyingBytesBuilder([int initialCapacity = 0])
      : _buffer = (initialCapacity <= 0) ? _emptyList : Uint8List(_pow2roundup(initialCapacity));

  @override
  void add(List<int> bytes) {
    int bytesLength = bytes.length;
    if (bytesLength == 0) return;
    int required = _length + bytesLength;
    if (_buffer.length < required) {
      _grow(required);
    }
    assert(_buffer.length >= required);
    if (bytes is Uint8List) {
      _buffer.setRange(_length, required, bytes);
    } else {
      for (int i = 0; i < bytesLength; i++) {
        _buffer[_length + i] = bytes[i];
      }
    }
    _length = required;
  }

  @override
  void addByte(int byte) {
    if (_buffer.length == _length) {
      // The grow algorithm always at least doubles.
      // If we added one to _length it would quadruple unnecessarily.
      _grow(_length);
    }
    assert(_buffer.length > _length);
    _buffer[_length] = byte;
    _length++;
  }

  void _grow(int required) {
    // We will create a list in the range of 2-4 times larger than
    // required.
    int newSize = required * 2;
    if (newSize < _INIT_SIZE) {
      newSize = _INIT_SIZE;
    } else {
      newSize = _pow2roundup(newSize);
    }
    var newBuffer = Uint8List(newSize);
    newBuffer.setRange(0, _buffer.length, _buffer);
    _buffer = newBuffer;
  }

  @override
  Uint8List takeBytes() {
    if (_length == 0) return _emptyList;
    var buffer = Uint8List.view(_buffer.buffer, _buffer.offsetInBytes, _length);
    clear();
    return buffer;
  }

  @override
  Uint8List toBytes() {
    if (_length == 0) return _emptyList;
    return Uint8List.fromList(Uint8List.view(_buffer.buffer, _buffer.offsetInBytes, _length));
  }

  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length != 0;

  @override
  void clear() {
    _length = 0;
    _buffer = _emptyList;
  }

  static int _pow2roundup(int x) {
    assert(x > 0);
    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x + 1;
  }
}

const int _OUTGOING_BUFFER_SIZE = 8 * 1024;

typedef _BytesConsumer = void Function(List<int> bytes);

class Incoming extends Stream<Uint8List> {
  final int _transferLength;
  final _dataCompleter = Completer<bool>();
  final Stream<Uint8List> _stream;

  bool fullBodyRead = false;

  // Common properties.
  final NativeHeaders headers;
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

  Incoming(this.headers, this._transferLength, this._stream);

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    hasSubscriber = true;
    return _stream.handleError((Object error) {
      throw HttpException((error as dynamic).message as String, uri: uri);
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

abstract class InboundMessage extends Stream<Uint8List> {
  final Incoming incoming;

  InboundMessage(this.incoming);

  NativeHeaders get headers => incoming.headers;
  String get protocolVersion => headers.protocolVersion;
  int get contentLength => headers.contentLength;
  bool get persistentConnection => headers.persistentConnection;
}

class NativeRequest extends InboundMessage {
  final NativeResponse response;

  final NativeServer _httpServer;

  final Connection _httpConnection;

  Uri? _requestedUri;

  NativeRequest(this.response, Incoming incoming, this._httpServer, this._httpConnection) : super(incoming) {
    if (headers.protocolVersion == '1.1') {
      response.headers
        ..chunkedTransferEncoding = true
        ..persistentConnection = headers.persistentConnection;
    }
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return incoming.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Uri get uri => incoming.uri!;

  Uri get requestedUri {
    var requestedUri = _requestedUri;
    if (requestedUri != null) return requestedUri;
    var proto = headers['x-forwarded-proto'];
    var scheme = proto != null
        ? proto.first
        : _httpConnection._socket is SecureSocket
            ? 'https'
            : 'http';
    var hostList = headers['x-forwarded-host'];
    String host;
    if (hostList != null) {
      host = hostList.first;
    } else {
      hostList = headers[HttpHeaders.hostHeader];
      if (hostList != null) {
        host = hostList.first;
      } else {
        host = '${_httpServer.address.host}:${_httpServer.port}';
      }
    }
    return _requestedUri = Uri.parse("$scheme://$host$uri");
  }

  String get method => incoming.method!;

  HttpConnectionInfo? get connectionInfo => _httpConnection.connectionInfo;

  X509Certificate? get certificate {
    var socket = _httpConnection._socket;
    if (socket is SecureSocket) return socket.peerCertificate;
    return null;
  }
}

class _StreamSinkImpl<T> implements StreamSink<T> {
  final StreamConsumer<T> _target;
  final _doneCompleter = Completer<void>();
  StreamController<T>? _controllerInstance;
  Completer? _controllerCompleter;
  bool _isClosed = false;
  bool _isBound = false;
  bool _hasError = false;

  _StreamSinkImpl(this._target);

  @override
  void add(T data) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    _controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    _controller.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<T> stream) {
    if (_isBound) {
      throw StateError('StreamSink is already bound to a stream');
    }
    _isBound = true;
    if (_hasError) return done;
    // Wait for any sync operations to complete.
    Future targetAddStream() {
      return _target.addStream(stream).whenComplete(() {
        _isBound = false;
      });
    }

    var controller = _controllerInstance;
    if (controller == null) return targetAddStream();
    var future = _controllerCompleter!.future;
    controller.close();
    return future.then((_) => targetAddStream());
  }

  Future flush() {
    if (_isBound) {
      throw StateError('StreamSink is bound to a stream');
    }
    var controller = _controllerInstance;
    if (controller == null) return Future.value(this);
    // Adding an empty stream-controller will return a future that will complete
    // when all data is done.
    _isBound = true;
    var future = _controllerCompleter!.future;
    controller.close();
    return future.whenComplete(() {
      _isBound = false;
    });
  }

  @override
  Future close() {
    if (_isBound) {
      throw StateError('StreamSink is bound to a stream');
    }
    if (!_isClosed) {
      _isClosed = true;
      var controller = _controllerInstance;
      if (controller != null) {
        controller.close();
      } else {
        _closeTarget();
      }
    }
    return done;
  }

  void _closeTarget() {
    _target.close().then(_completeDoneValue, onError: _completeDoneError);
  }

  @override
  Future get done => _doneCompleter.future;

  void _completeDoneValue(value) {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(value);
    }
  }

  void _completeDoneError(Object error, StackTrace stackTrace) {
    if (!_doneCompleter.isCompleted) {
      _hasError = true;
      _doneCompleter.completeError(error, stackTrace);
    }
  }

  StreamController<T> get _controller {
    if (_isBound) {
      throw StateError('StreamSink is bound to a stream');
    }
    if (_isClosed) {
      throw StateError('StreamSink is closed');
    }
    if (_controllerInstance == null) {
      _controllerInstance = StreamController<T>(sync: true);
      _controllerCompleter = Completer();
      _target.addStream(_controller.stream).then((_) {
        if (_isBound) {
          // A new stream takes over - forward values to that stream.
          _controllerCompleter!.complete(this);
          _controllerCompleter = null;
          _controllerInstance = null;
        } else {
          // No new stream, .close was called. Close _target.
          _closeTarget();
        }
      }, onError: (Object error, StackTrace stackTrace) {
        if (_isBound) {
          // A new stream takes over - forward errors to that stream.
          _controllerCompleter!.completeError(error, stackTrace);
          _controllerCompleter = null;
          _controllerInstance = null;
        } else {
          // No new stream. No need to close target, as it has already
          // failed.
          _completeDoneError(error, stackTrace);
        }
      });
    }
    return _controllerInstance!;
  }
}

class _IOSinkImpl extends _StreamSinkImpl<List<int>> implements IOSink {
  Encoding _encoding;
  bool _encodingMutable = true;

  _IOSinkImpl(StreamConsumer<List<int>> target, this._encoding) : super(target);

  @override
  Encoding get encoding => _encoding;

  @override
  set encoding(Encoding value) {
    if (!_encodingMutable) {
      throw StateError('IOSink encoding is not mutable');
    }
    _encoding = value;
  }

  @override
  void write(Object? obj) {
    String string = '$obj';
    if (string.isEmpty) return;
    super.add(_encoding.encode(string));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    Iterator iterator = objects.iterator;
    if (!iterator.moveNext()) return;
    if (separator.isEmpty) {
      do {
        write(iterator.current);
      } while (iterator.moveNext());
    } else {
      write(iterator.current);
      while (iterator.moveNext()) {
        write(separator);
        write(iterator.current);
      }
    }
  }

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }
}

abstract class _HttpOutboundMessage<T> extends _IOSinkImpl {
  // Used to mark when the body should be written. This is used for HEAD
  // requests and in error handling.
  bool _encodingSet = false;

  bool _bufferOutput = true;

  final Uri _uri;
  final Outgoing _outgoing;

  final NativeHeaders headers;

  _HttpOutboundMessage(Uri uri, String protocolVersion, Outgoing outgoing, {NativeHeaders? initialHeaders})
      : _uri = uri,
        headers = NativeHeaders(protocolVersion,
            defaultPortForScheme: uri.isScheme('https') ? HttpClient.defaultHttpsPort : HttpClient.defaultHttpPort,
            initialHeaders: initialHeaders),
        _outgoing = outgoing,
        super(outgoing, latin1) {
    _outgoing.outbound = this;
    _encodingMutable = false;
  }

  int get contentLength => headers.contentLength;
  set contentLength(int contentLength) {
    headers.contentLength = contentLength;
  }

  bool get persistentConnection => headers.persistentConnection;
  set persistentConnection(bool p) {
    headers.persistentConnection = p;
  }

  bool get bufferOutput => _bufferOutput;
  set bufferOutput(bool bufferOutput) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    _bufferOutput = bufferOutput;
  }

  @override
  Encoding get encoding {
    if (_encodingSet && _outgoing.headersWritten) {
      return _encoding;
    }
    String charset;
    var contentType = headers.contentType;
    if (contentType != null && contentType.charset != null) {
      charset = contentType.charset!;
    } else {
      charset = 'iso-8859-1';
    }
    return Encoding.getByName(charset) ?? latin1;
  }

  @override
  void add(List<int> data) {
    if (data.isEmpty) return;
    super.add(data);
  }

  @override
  void write(Object? obj) {
    if (!_encodingSet) {
      _encoding = encoding;
      _encodingSet = true;
    }
    super.write(obj);
  }

  void _writeHeader();

  bool get _isConnectionClosed => false;
}

class NativeResponse extends _HttpOutboundMessage<NativeResponse> {
  int _statusCode = 200;
  String? _reasonPhrase;
  List<Cookie>? _cookies;
  NativeRequest? _httpRequest;
  Duration? _deadline;
  Timer? _deadlineTimer;

  NativeResponse(Uri uri, String protocolVersion, Outgoing outgoing, NativeHeaders defaultHeaders, String? serverHeader)
      : super(uri, protocolVersion, outgoing, initialHeaders: defaultHeaders) {
    if (serverHeader != null) {
      headers.set(HttpHeaders.serverHeader, serverHeader);
    }
  }

  @override
  bool get _isConnectionClosed => _httpRequest!._httpConnection._isClosing;

  List<Cookie> get cookies => _cookies ??= <Cookie>[];

  int get statusCode => _statusCode;
  set statusCode(int statusCode) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    _statusCode = statusCode;
  }

  String get reasonPhrase => _findReasonPhrase(statusCode);
  set reasonPhrase(String reasonPhrase) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    _reasonPhrase = reasonPhrase;
  }

  Future<void> redirect(Uri location, {int status = HttpStatus.movedTemporarily}) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    statusCode = status;
    headers.set(HttpHeaders.locationHeader, location.toString());
    return close();
  }

  Future<Socket> detachSocket({bool writeHeaders = true}) {
    if (_outgoing.headersWritten) throw StateError('Headers already sent');
    deadline = null; // Be sure to stop any deadline.
    var future = _httpRequest!._httpConnection.detachSocket();
    if (writeHeaders) {
      var headersFuture = _outgoing.writeHeaders(drainRequest: false, setOutgoing: false);
      assert(headersFuture == null);
    } else {
      // Imitate having written the headers.
      _outgoing.headersWritten = true;
    }
    // Close connection so the socket is 'free'.
    close();
    done.catchError((_) {
      // Catch any error on done, as they automatically will be
      // propagated to the websocket.
    });
    return future;
  }

  HttpConnectionInfo? get connectionInfo => _httpRequest!.connectionInfo;

  Duration? get deadline => _deadline;

  set deadline(Duration? d) {
    _deadlineTimer?.cancel();
    _deadline = d;

    if (d == null) return;
    _deadlineTimer = Timer(d, () {
      _httpRequest!._httpConnection.destroy();
    });
  }

  @override
  void _writeHeader() {
    BytesBuilder buffer = _CopyingBytesBuilder(_OUTGOING_BUFFER_SIZE);

    // Write status line.
    if (headers.protocolVersion == '1.1') {
      buffer.add(Const.HTTP11);
    } else {
      buffer.add(Const.HTTP10);
    }
    buffer.addByte(CharCode.SP);
    buffer.add(statusCode.toString().codeUnits);
    buffer.addByte(CharCode.SP);
    buffer.add(reasonPhrase.codeUnits);
    buffer.addByte(CharCode.CR);
    buffer.addByte(CharCode.LF);

    headers.finalize();

    // Write headers.
    headers.build(buffer);
    buffer.addByte(CharCode.CR);
    buffer.addByte(CharCode.LF);
    Uint8List headerBytes = buffer.takeBytes();
    _outgoing.setHeader(headerBytes, headerBytes.length);
  }

  String _findReasonPhrase(int statusCode) {
    var reasonPhrase = _reasonPhrase;
    if (reasonPhrase != null) {
      return reasonPhrase;
    }

    switch (statusCode) {
      case HttpStatus.continue_:
        return 'Continue';
      case HttpStatus.switchingProtocols:
        return 'Switching Protocols';
      case HttpStatus.ok:
        return 'OK';
      case HttpStatus.created:
        return 'Created';
      case HttpStatus.accepted:
        return 'Accepted';
      case HttpStatus.nonAuthoritativeInformation:
        return 'Non-Authoritative Information';
      case HttpStatus.noContent:
        return 'No Content';
      case HttpStatus.resetContent:
        return 'Reset Content';
      case HttpStatus.partialContent:
        return 'Partial Content';
      case HttpStatus.multipleChoices:
        return 'Multiple Choices';
      case HttpStatus.movedPermanently:
        return 'Moved Permanently';
      case HttpStatus.found:
        return 'Found';
      case HttpStatus.seeOther:
        return 'See Other';
      case HttpStatus.notModified:
        return 'Not Modified';
      case HttpStatus.useProxy:
        return 'Use Proxy';
      case HttpStatus.temporaryRedirect:
        return 'Temporary Redirect';
      case HttpStatus.badRequest:
        return 'Bad Request';
      case HttpStatus.unauthorized:
        return 'Unauthorized';
      case HttpStatus.paymentRequired:
        return 'Payment Required';
      case HttpStatus.forbidden:
        return 'Forbidden';
      case HttpStatus.notFound:
        return 'Not Found';
      case HttpStatus.methodNotAllowed:
        return 'Method Not Allowed';
      case HttpStatus.notAcceptable:
        return 'Not Acceptable';
      case HttpStatus.proxyAuthenticationRequired:
        return 'Proxy Authentication Required';
      case HttpStatus.requestTimeout:
        return 'Request Time-out';
      case HttpStatus.conflict:
        return 'Conflict';
      case HttpStatus.gone:
        return 'Gone';
      case HttpStatus.lengthRequired:
        return 'Length Required';
      case HttpStatus.preconditionFailed:
        return 'Precondition Failed';
      case HttpStatus.requestEntityTooLarge:
        return 'Request Entity Too Large';
      case HttpStatus.requestUriTooLong:
        return 'Request-URI Too Long';
      case HttpStatus.unsupportedMediaType:
        return 'Unsupported Media Type';
      case HttpStatus.requestedRangeNotSatisfiable:
        return 'Requested range not satisfiable';
      case HttpStatus.expectationFailed:
        return 'Expectation Failed';
      case HttpStatus.internalServerError:
        return 'Internal Server Error';
      case HttpStatus.notImplemented:
        return 'Not Implemented';
      case HttpStatus.badGateway:
        return 'Bad Gateway';
      case HttpStatus.serviceUnavailable:
        return 'Service Unavailable';
      case HttpStatus.gatewayTimeout:
        return 'Gateway Time-out';
      case HttpStatus.httpVersionNotSupported:
        return 'Http Version not supported';
      default:
        return 'Status $statusCode';
    }
  }
}

// Used by _HttpOutgoing as a target of a chunked converter for gzip
// compression.
class _HttpGZipSink extends ByteConversionSink {
  final _BytesConsumer _consume;
  _HttpGZipSink(this._consume);

  @override
  void add(List<int> chunk) {
    _consume(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    if (chunk is Uint8List) {
      _consume(Uint8List.view(chunk.buffer, chunk.offsetInBytes + start, end - start));
    } else {
      _consume(chunk.sublist(start, end - start));
    }
  }

  @override
  void close() {}
}

// The _HttpOutgoing handles all of the following:
//  - Buffering
//  - GZip compression
//  - Content-Length validation.
//  - Errors.
//
// Most notable is the GZip compression, that uses a double-buffering system,
// one before gzip (_gzipBuffer) and one after (_buffer).
class Outgoing implements StreamConsumer<List<int>> {
  static const List<int> _footerAndChunk0Length = [
    CharCode.CR,
    CharCode.LF,
    0x30,
    CharCode.CR,
    CharCode.LF,
    CharCode.CR,
    CharCode.LF
  ];

  static const List<int> _chunk0Length = [0x30, CharCode.CR, CharCode.LF, CharCode.CR, CharCode.LF];

  final Completer<Socket> _doneCompleter = Completer<Socket>();
  final Socket socket;

  bool ignoreBody = false;
  bool headersWritten = false;

  Uint8List? _buffer;
  int _length = 0;

  Future? _closeFuture;

  bool chunked = false;
  int _pendingChunkedFooter = 0;

  int? contentLength;
  int _bytesWritten = 0;

  bool _gzip = false;
  ByteConversionSink? _gzipSink;
  // _gzipAdd is set iff the sink is being added to. It's used to specify where
  // gzipped data should be taken (sometimes a controller, sometimes a socket).
  _BytesConsumer? _gzipAdd;
  Uint8List? _gzipBuffer;
  int _gzipBufferLength = 0;

  bool _socketError = false;

  _HttpOutboundMessage? outbound;

  Outgoing(this.socket);

  // Returns either a future or 'null', if it was able to write headers
  // immediately.
  Future<void>? writeHeaders({bool drainRequest = true, bool setOutgoing = true}) {
    if (headersWritten) return null;
    headersWritten = true;
    Future<void>? drainFuture;
    bool gzip = false;
    var response = outbound!;
    if (response is NativeResponse) {
      // Server side.
      if (response._httpRequest!._httpServer.autoCompress &&
          response.bufferOutput &&
          response.headers.chunkedTransferEncoding) {
        List<String>? acceptEncodings = response._httpRequest!.headers[HttpHeaders.acceptEncodingHeader];
        List<String>? contentEncoding = response.headers[HttpHeaders.contentEncodingHeader];
        if (acceptEncodings != null &&
            contentEncoding == null &&
            acceptEncodings
                .expand((list) => list.split(','))
                .any((encoding) => encoding.trim().toLowerCase() == 'gzip')) {
          response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          gzip = true;
        }
      }
      if (drainRequest && !response._httpRequest!.incoming.hasSubscriber) {
        drainFuture = response._httpRequest!.drain<void>().catchError((_) {});
      }
    } else {
      drainRequest = false;
    }
    if (!ignoreBody) {
      if (setOutgoing) {
        int contentLength = response.headers.contentLength;
        if (response.headers.chunkedTransferEncoding) {
          chunked = true;
          if (gzip) this.gzip = true;
        } else if (contentLength >= 0) {
          this.contentLength = contentLength;
        }
      }
      if (drainFuture != null) {
        return drainFuture.then((_) => response._writeHeader());
      }
    }
    response._writeHeader();
    return null;
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    if (_socketError) {
      stream.listen(null).cancel();
      return Future.value(outbound);
    }
    if (ignoreBody) {
      stream.drain().catchError((_) {});
      var future = writeHeaders();
      if (future != null) {
        return future.then((_) => close());
      }
      return close();
    }
    // Use new stream so we are able to pause (see below listen). The
    // alternative is to use stream.extand, but that won't give us a way of
    // pausing.
    var controller = StreamController<List<int>>(sync: true);

    void onData(List<int> data) {
      if (_socketError) return;
      if (data.isEmpty) return;
      if (chunked) {
        if (_gzip) {
          _gzipAdd = controller.add;
          _addGZipChunk(data, _gzipSink!.add);
          _gzipAdd = null;
          return;
        }
        _addChunk(_chunkHeader(data.length), controller.add);
        _pendingChunkedFooter = 2;
      } else {
        var contentLength = this.contentLength;
        if (contentLength != null) {
          _bytesWritten += data.length;
          if (_bytesWritten > contentLength) {
            controller.addError(HttpException('Content size exceeds specified contentLength. '
                '$_bytesWritten bytes written while expected '
                '$contentLength. '
                '[${String.fromCharCodes(data)}]'));
            return;
          }
        }
      }
      _addChunk(data, controller.add);
    }

    var sub = stream.listen(onData, onError: controller.addError, onDone: controller.close, cancelOnError: true);
    controller.onPause = sub.pause;
    controller.onResume = sub.resume;
    // Write headers now that we are listening to the stream.
    if (!headersWritten) {
      var future = writeHeaders();
      if (future != null) {
        // While incoming is being drained, the pauseFuture is non-null. Pause
        // output until it's drained.
        sub.pause(future);
      }
    }
    return socket.addStream(controller.stream).then((_) {
      return outbound;
    }, onError: (Object error, [StackTrace? stackTrace]) {
      // Be sure to close it in case of an error.
      if (_gzip) _gzipSink!.close();
      _socketError = true;
      _doneCompleter.completeError(error, stackTrace);
      if (_ignoreError(error)) {
        return outbound;
      } else {
        throw error;
      }
    });
  }

  @override
  Future<void> close() {
    // If we are already closed, return that future.
    var closeFuture = _closeFuture;
    if (closeFuture != null) return closeFuture;

    var outbound = this.outbound!;
    // If we earlier saw an error, return immediate. The notification to
    // _Http*Connection is already done.
    if (_socketError) return Future.value(outbound);
    if (outbound._isConnectionClosed) return Future.value(outbound);
    if (!headersWritten && !ignoreBody) {
      if (outbound.headers.contentLength == -1) {
        // If no body was written, ignoreBody is false (it's not a HEAD
        // request) and the content-length is unspecified, set contentLength to
        // 0.
        outbound.headers.chunkedTransferEncoding = false;
        outbound.headers.contentLength = 0;
      } else if (outbound.headers.contentLength > 0) {
        var error = HttpException(
            'No content even though contentLength was specified to be '
            'greater than 0: ${outbound.headers.contentLength}.',
            uri: outbound._uri);
        _doneCompleter.completeError(error);
        return _closeFuture = Future.error(error);
      }
    }
    // If contentLength was specified, validate it.
    var contentLength = this.contentLength;
    if (contentLength != null) {
      if (_bytesWritten < contentLength) {
        var error = HttpException(
            'Content size below specified contentLength. '
            ' $_bytesWritten bytes written but expected '
            '$contentLength.',
            uri: outbound._uri);
        _doneCompleter.completeError(error);
        return _closeFuture = Future.error(error);
      }
    }

    Future finalize() {
      // In case of chunked encoding (and gzip), handle remaining gzip data and
      // append the 'footer' for chunked encoding.
      if (chunked) {
        if (_gzip) {
          _gzipAdd = socket.add;
          if (_gzipBufferLength > 0) {
            _gzipSink!.add(Uint8List.view(_gzipBuffer!.buffer, _gzipBuffer!.offsetInBytes, _gzipBufferLength));
          }
          _gzipBuffer = null;
          _gzipSink!.close();
          _gzipAdd = null;
        }
        _addChunk(_chunkHeader(0), socket.add);
      }
      // Add any remaining data in the buffer.
      if (_length > 0) {
        socket.add(Uint8List.view(_buffer!.buffer, _buffer!.offsetInBytes, _length));
      }
      // Clear references, for better GC.
      _buffer = null;
      // And finally flush it. As we support keep-alive, never close it from
      // here. Once the socket is flushed, we'll be able to reuse it (signaled
      // by the 'done' future).
      return socket.flush().then((_) {
        _doneCompleter.complete(socket);
        return outbound;
      }, onError: (Object error, [StackTrace? stackTrace]) {
        _doneCompleter.completeError(error, stackTrace);
        if (_ignoreError(error)) {
          return outbound;
        } else {
          throw error;
        }
      });
    }

    var future = writeHeaders();
    if (future != null) {
      return _closeFuture = future.whenComplete(finalize);
    }
    return _closeFuture = finalize();
  }

  Future<Socket> get done => _doneCompleter.future;

  void setHeader(List<int> data, int length) {
    assert(_length == 0);
    _buffer = data as Uint8List;
    _length = length;
  }

  set gzip(bool value) {
    _gzip = value;
    if (value) {
      _gzipBuffer = Uint8List(_OUTGOING_BUFFER_SIZE);
      assert(_gzipSink == null);
      _gzipSink = ZLibEncoder(gzip: true).startChunkedConversion(_HttpGZipSink((data) {
        // We are closing down prematurely, due to an error. Discard.
        if (_gzipAdd == null) return;
        _addChunk(_chunkHeader(data.length), _gzipAdd!);
        _pendingChunkedFooter = 2;
        _addChunk(data, _gzipAdd!);
      }));
    }
  }

  bool _ignoreError(Object error) => (error is SocketException || error is TlsException) && outbound is NativeResponse;

  void _addGZipChunk(List<int> chunk, void Function(List<int> data) add) {
    var bufferOutput = outbound!.bufferOutput;
    if (!bufferOutput) {
      add(chunk);
      return;
    }
    var gzipBuffer = _gzipBuffer!;
    if (chunk.length > gzipBuffer.length - _gzipBufferLength) {
      add(Uint8List.view(gzipBuffer.buffer, gzipBuffer.offsetInBytes, _gzipBufferLength));
      _gzipBuffer = Uint8List(_OUTGOING_BUFFER_SIZE);
      _gzipBufferLength = 0;
    }
    if (chunk.length > _OUTGOING_BUFFER_SIZE) {
      add(chunk);
    } else {
      var currentLength = _gzipBufferLength;
      var newLength = currentLength + chunk.length;
      _gzipBuffer!.setRange(currentLength, newLength, chunk);
      _gzipBufferLength = newLength;
    }
  }

  void _addChunk(List<int> chunk, void Function(List<int> data) add) {
    var bufferOutput = outbound!.bufferOutput;
    if (!bufferOutput) {
      if (_buffer != null) {
        // If _buffer is not null, we have not written the header yet. Write
        // it now.
        add(Uint8List.view(_buffer!.buffer, _buffer!.offsetInBytes, _length));
        _buffer = null;
        _length = 0;
      }
      add(chunk);
      return;
    }
    if (chunk.length > _buffer!.length - _length) {
      add(Uint8List.view(_buffer!.buffer, _buffer!.offsetInBytes, _length));
      _buffer = Uint8List(_OUTGOING_BUFFER_SIZE);
      _length = 0;
    }
    if (chunk.length > _OUTGOING_BUFFER_SIZE) {
      add(chunk);
    } else {
      _buffer!.setRange(_length, _length + chunk.length, chunk);
      _length += chunk.length;
    }
  }

  List<int> _chunkHeader(int length) {
    const hexDigits = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46];
    if (length == 0) {
      if (_pendingChunkedFooter == 2) return _footerAndChunk0Length;
      return _chunk0Length;
    }
    int size = _pendingChunkedFooter;
    int len = length;
    // Compute a fast integer version of (log(length + 1) / log(16)).ceil().
    while (len > 0) {
      size++;
      len >>= 4;
    }
    var footerAndHeader = Uint8List(size + 2);
    if (_pendingChunkedFooter == 2) {
      footerAndHeader[0] = CharCode.CR;
      footerAndHeader[1] = CharCode.LF;
    }
    int index = size;
    while (index > _pendingChunkedFooter) {
      footerAndHeader[--index] = hexDigits[length & 15];
      length = length >> 4;
    }
    footerAndHeader[size + 0] = CharCode.CR;
    footerAndHeader[size + 1] = CharCode.LF;
    return footerAndHeader;
  }
}

class Connection extends LinkedListEntry<Connection> with _ServiceObject {
  static const _ACTIVE = 0;
  static const _IDLE = 1;
  static const _CLOSING = 2;
  static const _DETACHED = 3;

  // Use HashMap, as we don't need to keep order.
  static final Map<int, Connection> _connections = HashMap<int, Connection>();

  final Socket _socket;
  final NativeServer _httpServer;
  final Parser _httpParser;
  int _state = _IDLE;
  StreamSubscription? _subscription;
  bool _idleMark = false;
  Future? _streamFuture;

  Connection(this._socket, this._httpServer) : _httpParser = Parser.requestParser() {
    _connections[_serviceId] = this;
    _httpParser.listenToStream(_socket);
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
      var outgoing = Outgoing(_socket);
      var response = NativeResponse(incoming.uri!, incoming.headers.protocolVersion, outgoing,
          _httpServer.defaultResponseHeaders, _httpServer.serverHeader);
      // Parser found badRequest and sent out Response.
      if (incoming.statusCode == HttpStatus.badRequest) {
        response.statusCode = HttpStatus.badRequest;
      }
      var request = NativeRequest(response, incoming, _httpServer, this);
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
      outgoing.ignoreBody = request.method == 'HEAD';
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

    var detachedIncoming = _httpParser.detachIncoming();

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
}

// HTTP server waiting for socket connections.
class NativeServer extends Stream<NativeRequest> with _ServiceObject {
  // Use default Map so we keep order.
  static final Map<int, NativeServer> _servers = <int, NativeServer>{};

  String? serverHeader;
  final NativeHeaders defaultResponseHeaders = _initDefaultResponseHeaders();
  bool autoCompress = false;

  Duration? _idleTimeout;
  Timer? _idleTimer;

  static Future<NativeServer> bind(Object address, int port,
      {int backlog = 0, bool v6Only = false, bool shared = false}) {
    return ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared)
        .then<NativeServer>((socket) {
      return NativeServer._(socket, true);
    });
  }

  static Future<NativeServer> bindSecure(Object address, int port, SecurityContext? context,
      {int backlog = 0, bool v6Only = false, bool requestClientCertificate = false, bool shared = false}) {
    return SecureServerSocket.bind(address, port, context,
            backlog: backlog, v6Only: v6Only, requestClientCertificate: requestClientCertificate, shared: shared)
        .then<NativeServer>((socket) {
      return NativeServer._(socket, true);
    });
  }

  NativeServer._(this._serverSocket, this._closeServer) : _controller = StreamController<NativeRequest>(sync: true) {
    _controller.onCancel = close;
    idleTimeout = const Duration(seconds: 120);
    _servers[_serviceId] = this;
  }

  NativeServer.listenOn(this._serverSocket)
      : _closeServer = false,
        _controller = StreamController<NativeRequest>(sync: true) {
    _controller.onCancel = close;
    idleTimeout = const Duration(seconds: 120);
    _servers[_serviceId] = this;
  }

  static NativeHeaders _initDefaultResponseHeaders() {
    var defaultResponseHeaders = NativeHeaders('1.1');
    defaultResponseHeaders.contentType = ContentType.text;
    defaultResponseHeaders.set('X-Frame-Options', 'SAMEORIGIN');
    defaultResponseHeaders.set('X-Content-Type-Options', 'nosniff');
    defaultResponseHeaders.set('X-XSS-Protection', '1; mode=block');
    return defaultResponseHeaders;
  }

  Duration? get idleTimeout => _idleTimeout;

  set idleTimeout(Duration? duration) {
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
  StreamSubscription<NativeRequest> listen(void Function(NativeRequest event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _serverSocket.listen((Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }
      // Accept the client connection.
      Connection connection = Connection(socket, this);
      _idleConnections.add(connection);
    }, onError: (Object error, [StackTrace? stackTrace]) {
      // Ignore HandshakeExceptions as they are bound to a single request,
      // and are not fatal for the server.
      if (error is! HandshakeException) {
        _controller.addError(error, stackTrace);
      }
    }, onDone: _controller.close);
    return _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Future<void> close({bool force = false}) {
    closed = true;
    Future<void> result;

    if (_closeServer) {
      result = (_serverSocket as dynamic).close() as Future<void>;
    } else {
      result = Future<void>.value();
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

  int get port {
    if (closed) throw HttpException('NativeServer is not bound to a socket');
    return (_serverSocket as dynamic).port as int;
  }

  InternetAddress get address {
    if (closed) throw HttpException('NativeServer is not bound to a socket');
    return (_serverSocket as dynamic).address as InternetAddress;
  }

  void _handleRequest(NativeRequest request) {
    if (!closed) {
      _controller.add(request);
    } else {
      request._httpConnection.destroy();
    }
  }

  void _connectionClosed(Connection connection) {
    // Remove itself from either idle or active connections.
    connection.unlink();
  }

  void _markIdle(Connection connection) {
    _activeConnections.remove(connection);
    _idleConnections.add(connection);
  }

  void _markActive(Connection connection) {
    _idleConnections.remove(connection);
    _activeConnections.add(connection);
  }

  HttpConnectionsInfo connectionsInfo() {
    HttpConnectionsInfo result = HttpConnectionsInfo();
    result.total = _activeConnections.length + _idleConnections.length;
    for (var conn in _activeConnections) {
      if (conn._isActive) {
        result.active++;
      } else {
        assert(conn._isClosing);
        result.closing++;
      }
    }
    for (var conn in _idleConnections) {
      result.idle++;
      assert(conn._isIdle);
    }
    return result;
  }

  // Indicated if the http server has been closed.
  bool closed = false;

  // The server listen socket. Untyped as it can be both ServerSocket and
  // SecureServerSocket.
  final Stream<Socket> _serverSocket;
  final bool _closeServer;

  // Set of currently connected clients.
  final LinkedList<Connection> _activeConnections = LinkedList<Connection>();
  final LinkedList<Connection> _idleConnections = LinkedList<Connection>();
  final StreamController<NativeRequest> _controller;
}

class _HttpConnectionInfo implements HttpConnectionInfo {
  @override
  InternetAddress remoteAddress;
  @override
  int remotePort;
  @override
  int localPort;

  _HttpConnectionInfo(this.remoteAddress, this.remotePort, this.localPort);

  static _HttpConnectionInfo? create(Socket? socket) {
    if (socket == null) {
      return null;
    }

    try {
      return _HttpConnectionInfo(socket.remoteAddress, socket.remotePort, socket.port);
    } catch (error) {
      // pass
    }

    return null;
  }
}

class _DetachedSocket extends Stream<Uint8List> implements Socket {
  final Stream<Uint8List> _incoming;
  final Socket _socket;

  _DetachedSocket(this._socket, this._incoming);

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _incoming.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Encoding get encoding => _socket.encoding;

  @override
  set encoding(Encoding value) {
    _socket.encoding = value;
  }

  @override
  void write(Object? obj) {
    _socket.write(obj);
  }

  @override
  void writeln([Object? obj = '']) {
    _socket.writeln(obj);
  }

  @override
  void writeCharCode(int charCode) {
    _socket.writeCharCode(charCode);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    _socket.writeAll(objects, separator);
  }

  @override
  void add(List<int> bytes) {
    _socket.add(bytes);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return _socket.addStream(stream);
  }

  @override
  void destroy() {
    _socket.destroy();
  }

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> get done => _socket.done;

  @override
  int get port => _socket.port;

  @override
  InternetAddress get address => _socket.address;

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  int get remotePort => _socket.remotePort;

  @override
  bool setOption(SocketOption option, bool enabled) {
    return _socket.setOption(option, enabled);
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    return _socket.getRawOption(option);
  }

  @override
  void setRawOption(RawSocketOption option) {
    _socket.setRawOption(option);
  }
}
