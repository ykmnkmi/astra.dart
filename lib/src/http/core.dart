part of '../../http.dart';

abstract class ServiceObject {
  static int nextServiceId = 1;

  final int serviceId = nextServiceId += 1;
}

class CopyingBytesBuilder implements BytesBuilder {
  // Start with 1024 bytes.
  static const int initSize = 1024;

  static final Uint8List emptyList = Uint8List(0);

  CopyingBytesBuilder([int initialCapacity = 0])
      : buffer = (initialCapacity <= 0) ? emptyList : Uint8List(_pow2roundup(initialCapacity));

  @override
  int length = 0;

  Uint8List buffer;

  @override
  bool get isEmpty {
    return length == 0;
  }

  @override
  bool get isNotEmpty {
    return length != 0;
  }

  @override
  void add(List<int> bytes) {
    int bytesLength = bytes.length;

    if (bytesLength == 0) return;

    int required = length + bytesLength;

    if (buffer.length < required) {
      grow(required);
    }

    assert(buffer.length >= required);

    if (bytes is Uint8List) {
      buffer.setRange(length, required, bytes);
    } else {
      for (int i = 0; i < bytesLength; i++) {
        buffer[length + i] = bytes[i];
      }
    }

    length = required;
  }

  @override
  void addByte(int byte) {
    if (buffer.length == length) {
      // The grow algorithm always at least doubles.
      // If we added one to _length it would quadruple unnecessarily.
      grow(length);
    }

    assert(buffer.length > length);
    buffer[length] = byte;
    length += 1;
  }

  void grow(int required) {
    // We will create a list in the range of 2-4 times larger than
    // required.
    var newSize = required * 2;

    if (newSize < initSize) {
      newSize = initSize;
    } else {
      newSize = _pow2roundup(newSize);
    }

    var newBuffer = Uint8List(newSize);
    newBuffer.setRange(0, buffer.length, buffer);
    buffer = newBuffer;
  }

  @override
  Uint8List takeBytes() {
    if (length == 0) {
      return emptyList;
    }

    var buffer = Uint8List.view(this.buffer.buffer, this.buffer.offsetInBytes, length);
    clear();
    return buffer;
  }

  @override
  Uint8List toBytes() {
    if (length == 0) {
      return emptyList;
    }

    return Uint8List.fromList(Uint8List.view(buffer.buffer, buffer.offsetInBytes, length));
  }

  @override
  void clear() {
    length = 0;
    buffer = emptyList;
  }

  static int _pow2roundup(int x) {
    assert(x > 0);
    x -= 1;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x + 1;
  }
}

const int outgoingBufferSize = 8 * 1024;

typedef BytesConsumer = void Function(List<int> bytes);

class Incoming extends Stream<Uint8List> {
  Incoming(this.headers, this.transferLength, this.stream);

  final NativeHeaders headers;

  final int transferLength;

  final Stream<Uint8List> stream;

  final Completer<bool> completer = Completer<bool>();

  bool fullBodyRead = false;

  bool upgraded = false;

  String? method;

  Uri? uri;

  bool hasSubscriber = false;

  Future<bool> get dataDone {
    return completer.future;
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    hasSubscriber = true;

    // TODO: remove dynamic
    void handleError(dynamic error) {
      throw HttpException(error.message as String, uri: uri);
    }

    return stream.handleError(handleError).listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }

  void close(bool closing) {
    fullBodyRead = true;
    hasSubscriber = true;
    completer.complete(closing);
  }
}

abstract class InboundMessage extends Stream<Uint8List> {
  InboundMessage(this.incoming);

  final Incoming incoming;

  NativeHeaders get headers {
    return incoming.headers;
  }

  String get protocolVersion {
    return headers.protocolVersion;
  }

  int get contentLength {
    return headers.contentLength;
  }

  bool get persistentConnection {
    return headers.persistentConnection;
  }
}

class NativeRequest extends InboundMessage implements AstraRequest {
  NativeRequest(Incoming incoming, this.server, this.connection, this.response) : super(incoming) {
    if (headers.protocolVersion == '1.1') {
      response.headers
        ..chunkedTransferEncoding = true
        ..persistentConnection = headers.persistentConnection;
    }
  }

  final NativeServer server;

  final Connection connection;

  @override
  final AstraResponse response;

  Uri? parsedUri;

  @override
  Uri get uri {
    return incoming.uri!;
  }

  @override
  Uri get requestedUri {
    var requestedUri = parsedUri;

    if (requestedUri != null) {
      return requestedUri;
    }

    var proto = headers['x-forwarded-proto'];
    String scheme;

    if (proto != null) {
      scheme = proto.first;
    } else {
      scheme = connection.socket is SecureSocket ? 'https' : 'http';
    }

    var hostList = headers['x-forwarded-host'];
    String host;

    if (hostList == null) {
      hostList = headers[AstraHeaders.hostHeader];

      if (hostList != null) {
        host = hostList.first;
      } else {
        host = '${server.address.host}:${server.port}';
      }
    } else {
      host = hostList.first;
    }

    return parsedUri = Uri.parse('$scheme://$host$uri');
  }

  @override
  String get method {
    return incoming.method!;
  }

  @override
  X509Certificate? get certificate {
    var socket = connection.socket;
    if (socket is SecureSocket) return socket.peerCertificate;
    return null;
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    return incoming.listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }
}

class StreamSinkImpl<T> implements StreamSink<T> {
  StreamSinkImpl(this.target);

  final StreamConsumer<T> target;

  final Completer<void> doneCmpleter = Completer<void>();

  StreamController<T>? controllerInstance;

  Completer<Object?>? controllerCompleter;

  bool isClosed = false;

  bool isBound = false;

  bool hasError = false;

  @override
  Future<void> get done {
    return doneCmpleter.future;
  }

  @override
  void add(T data) {
    if (isClosed) {
      throw StateError('StreamSink is closed');
    }

    controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (isClosed) {
      throw StateError('StreamSink is closed');
    }
    controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<T> stream) {
    if (isBound) {
      throw StateError('StreamSink is already bound to a stream');
    }

    isBound = true;

    if (hasError) {
      return done;
    }

    // Wait for any sync operations to complete.
    Future<void> targetAddStream() {
      void onComplete() {
        isBound = false;
      }

      return target.addStream(stream).whenComplete(onComplete);
    }

    var controller = controllerInstance;

    if (controller == null) {
      return targetAddStream();
    }

    var future = controllerCompleter!.future;
    controller.close();

    void onDone(Object? result) {
      targetAddStream();
    }

    return future.then<void>(onDone);
  }

  Future<void> flush() {
    if (isBound) {
      throw StateError('StreamSink is bound to a stream');
    }

    var controller = controllerInstance;

    if (controller == null) {
      return Future<void>.value();
    }

    // Adding an empty stream-controller will return a future that will complete
    // when all data is done.
    isBound = true;

    var future = controllerCompleter!.future;
    controller.close();

    void onComplete() {
      isBound = false;
    }

    return future.whenComplete(onComplete);
  }

  @override
  Future<void> close() {
    if (isBound) {
      throw StateError('StreamSink is bound to a stream');
    }

    if (!isClosed) {
      isClosed = true;

      var controller = controllerInstance;

      if (controller != null) {
        controller.close();
      } else {
        closeTarget();
      }
    }

    return done;
  }

  Future<void> closeTarget() {
    return target.close().then<void>(completeDoneValue, onError: completeDoneError);
  }

  void completeDoneValue(Object? result) {
    if (doneCmpleter.isCompleted) {
      return;
    }

    doneCmpleter.complete();
  }

  void completeDoneError(Object error, StackTrace stackTrace) {
    if (doneCmpleter.isCompleted) {
      return;
    }

    hasError = true;
    doneCmpleter.completeError(error, stackTrace);
  }

  StreamController<T> get controller {
    if (isBound) {
      throw StateError('StreamSink is bound to a stream');
    }

    if (isClosed) {
      throw StateError('StreamSink is closed');
    }

    if (controllerInstance == null) {
      controllerInstance = StreamController<T>(sync: true);
      controllerCompleter = Completer();

      void onDone(Object? result) {
        if (isBound) {
          // A new stream takes over - forward values to that stream.
          controllerCompleter!.complete(this);
          controllerCompleter = null;
          controllerInstance = null;
        } else {
          // No new stream, .close was called. Close _target.
          closeTarget();
        }
      }

      void onError(Object error, StackTrace stackTrace) {
        if (isBound) {
          // A new stream takes over - forward errors to that stream.
          controllerCompleter!.completeError(error, stackTrace);
          controllerCompleter = null;
          controllerInstance = null;
        } else {
          // No new stream. No need to close target, as it has already
          // failed.
          completeDoneError(error, stackTrace);
        }
      }

      target.addStream(controller.stream).then<void>(onDone, onError: onError);
    }

    return controllerInstance!;
  }
}

class IOSinkImpl extends StreamSinkImpl<List<int>> implements IOSink {
  IOSinkImpl(StreamConsumer<List<int>> target, this.currentEnconding) : super(target);

  Encoding currentEnconding;

  bool encodingMutable = true;

  @override
  Encoding get encoding {
    return currentEnconding;
  }

  @override
  set encoding(Encoding value) {
    if (encodingMutable) {
      currentEnconding = value;
    }

    throw StateError('IOSink encoding is not mutable');
  }

  @override
  void write(Object? object) {
    var string = object.toString();

    if (string.isEmpty) {
      return;
    }

    super.add(currentEnconding.encode(string));
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    var iterator = objects.iterator;

    if (iterator.moveNext()) {
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

abstract class OutboundMessage<T> extends IOSinkImpl {
  OutboundMessage(this.uri, String protocolVersion, Outgoing outgoing)
      : headers = NativeHeaders(protocolVersion, defaultPortForScheme: uri.isScheme('https') ? 80 : 443),
        _outgoing = outgoing,
        super(outgoing, latin1) {
    _outgoing.outbound = this;
    encodingMutable = false;
  }

  final Uri uri;

  final NativeHeaders headers;

  final Outgoing _outgoing;

  bool encodingSet = false;

  bool buffer = true;

  bool get isConnectionClosed {
    return false;
  }

  int get contentLength {
    return headers.contentLength;
  }

  set contentLength(int contentLength) {
    headers.contentLength = contentLength;
  }

  bool get persistentConnection {
    return headers.persistentConnection;
  }

  set persistentConnection(bool persistentConnection) {
    headers.persistentConnection = persistentConnection;
  }

  bool get bufferOutput {
    return buffer;
  }

  set bufferOutput(bool bufferOutput) {
    if (_outgoing.headersWritten) {
      throw StateError('Header already sent');
    }

    buffer = bufferOutput;
  }

  @override
  Encoding get encoding {
    if (encodingSet && _outgoing.headersWritten) {
      return currentEnconding;
    }

    var contentType = headers.contentType;
    String charset;

    if (contentType != null && contentType.charset != null) {
      charset = contentType.charset!;
    } else {
      charset = 'iso-8859-1';
    }

    return Encoding.getByName(charset) ?? latin1;
  }

  @override
  void add(List<int> data) {
    if (data.isEmpty) {
      return;
    }

    super.add(data);
  }

  @override
  void write(Object? object) {
    if (!encodingSet) {
      currentEnconding = encoding;
      encodingSet = true;
    }

    super.write(object);
  }

  void writeHeader();
}

class NativeResponse extends OutboundMessage<AstraResponse> implements AstraResponse {
  int _statusCode = 200;
  String? _reasonPhrase;
  NativeRequest? _httpRequest;
  Duration? _deadline;
  Timer? _deadlineTimer;

  NativeResponse(Uri uri, String protocolVersion, Outgoing outgoing, AstraHeaders defaultHeaders, String? serverHeader)
      : super(uri, protocolVersion, outgoing, initialHeaders: defaultHeaders as NativeHeaders) {
    if (serverHeader != null) {
      headers.set(AstraHeaders.serverHeader, serverHeader);
    }
  }

  @override
  bool get isConnectionClosed => _httpRequest!.connection._isClosing;

  @override
  int get statusCode => _statusCode;
  @override
  set statusCode(int statusCode) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    _statusCode = statusCode;
  }

  @override
  String get reasonPhrase => _findReasonPhrase(statusCode);
  @override
  set reasonPhrase(String reasonPhrase) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    _reasonPhrase = reasonPhrase;
  }

  @override
  Future<void> redirect(Uri location, {int status = HttpStatus.movedTemporarily}) {
    if (_outgoing.headersWritten) throw StateError('Header already sent');
    statusCode = status;
    headers.set(AstraHeaders.locationHeader, location.toString());
    return close();
  }

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    if (_outgoing.headersWritten) throw StateError('Headers already sent');
    deadline = null; // Be sure to stop any deadline.
    var future = _httpRequest!.connection.detachSocket();
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

  @override
  Duration? get deadline => _deadline;

  @override
  set deadline(Duration? d) {
    _deadlineTimer?.cancel();
    _deadline = d;

    if (d == null) return;
    _deadlineTimer = Timer(d, () {
      _httpRequest!.connection.destroy();
    });
  }

  @override
  void writeHeader() {
    BytesBuilder buffer = CopyingBytesBuilder(outgoingBufferSize);

    // Write status line.
    if (headers.protocolVersion == '1.1') {
      buffer.add(Constants.http11);
    } else {
      buffer.add(Constants.http10);
    }
    buffer.addByte(CharCodes.sp);
    buffer.add(statusCode.toString().codeUnits);
    buffer.addByte(CharCodes.sp);
    buffer.add(reasonPhrase.codeUnits);
    buffer.addByte(CharCodes.cr);
    buffer.addByte(CharCodes.lf);
    headers._finalize();

    // Write headers.
    headers._build(buffer);
    buffer.addByte(CharCodes.cr);
    buffer.addByte(CharCodes.lf);
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

class _HttpGZipSink extends ByteConversionSink {
  final BytesConsumer _consume;
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
    CharCodes.cr,
    CharCodes.lf,
    0x30,
    CharCodes.cr,
    CharCodes.lf,
    CharCodes.cr,
    CharCodes.lf
  ];

  static const List<int> _chunk0Length = [0x30, CharCodes.cr, CharCodes.lf, CharCodes.cr, CharCodes.lf];

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
  BytesConsumer? _gzipAdd;
  Uint8List? _gzipBuffer;
  int _gzipBufferLength = 0;

  bool _socketError = false;

  OutboundMessage? outbound;

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
      if (response._httpRequest!.server.autoCompress &&
          response.bufferOutput &&
          response.headers.chunkedTransferEncoding) {
        List<String>? acceptEncodings = response._httpRequest!.headers[AstraHeaders.acceptEncodingHeader];
        List<String>? contentEncoding = response.headers[AstraHeaders.contentEncodingHeader];
        if (acceptEncodings != null &&
            contentEncoding == null &&
            acceptEncodings
                .expand((list) => list.split(','))
                .any((encoding) => encoding.trim().toLowerCase() == 'gzip')) {
          response.headers.set(AstraHeaders.contentEncodingHeader, 'gzip');
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
        return drainFuture.then((_) => response.writeHeader());
      }
    }
    response.writeHeader();
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
    }, onError: (Object error, StackTrace? stackTrace) {
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
  Future close() {
    // If we are already closed, return that future.
    var closeFuture = _closeFuture;
    if (closeFuture != null) return closeFuture;

    var outbound = this.outbound!;
    // If we earlier saw an error, return immediate. The notification to
    // _Http*Connection is already done.
    if (_socketError) return Future.value(outbound);
    if (outbound.isConnectionClosed) return Future.value(outbound);
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
            uri: outbound.uri);
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
            uri: outbound.uri);
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
      }, onError: (Object error, StackTrace? stackTrace) {
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
      _gzipBuffer = Uint8List(outgoingBufferSize);
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

  bool _ignoreError(Object? error) => (error is SocketException || error is TlsException) && outbound is AstraResponse;

  void _addGZipChunk(List<int> chunk, void Function(List<int> data) add) {
    var bufferOutput = outbound!.bufferOutput;
    if (!bufferOutput) {
      add(chunk);
      return;
    }
    var gzipBuffer = _gzipBuffer!;
    if (chunk.length > gzipBuffer.length - _gzipBufferLength) {
      add(Uint8List.view(gzipBuffer.buffer, gzipBuffer.offsetInBytes, _gzipBufferLength));
      _gzipBuffer = Uint8List(outgoingBufferSize);
      _gzipBufferLength = 0;
    }
    if (chunk.length > outgoingBufferSize) {
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
      _buffer = Uint8List(outgoingBufferSize);
      _length = 0;
    }
    if (chunk.length > outgoingBufferSize) {
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
      size += 1;
      len >>= 4;
    }
    var footerAndHeader = Uint8List(size + 2);
    if (_pendingChunkedFooter == 2) {
      footerAndHeader[0] = CharCodes.cr;
      footerAndHeader[1] = CharCodes.lf;
    }
    int index = size;
    while (index > _pendingChunkedFooter) {
      footerAndHeader[--index] = hexDigits[length & 15];
      length = length >> 4;
    }
    footerAndHeader[size + 0] = CharCodes.cr;
    footerAndHeader[size + 1] = CharCodes.lf;
    return footerAndHeader;
  }
}

class Connection extends LinkedListEntry<Connection> with ServiceObject {
  static const int active = 0, idle = 1, closing = 2, detached = 3;

  // Use HashMap, as we don't need to keep order.
  static final Map<int, Connection> connections = HashMap<int, Connection>();

  final Socket socket;

  final NativeServer server;

  final Parser parser;

  int state = idle;

  StreamSubscription? subscription;

  bool idleMark = false;

  Future? streamFuture;

  Connection(this.socket, this.server) : parser = Parser() {
    connections[serviceId] = this;
    parser.listenToStream(socket);
    subscription = parser.listen((incoming) {
      server.markActive(this);
      // If the incoming was closed, close the connection.
      incoming.dataDone.then((closing) {
        if (closing) destroy();
      });
      // Only handle one incoming request at the time. Keep the
      // stream paused until the request has been send.
      subscription!.pause();
      state = active;

      var outgoing = Outgoing(socket);
      var response = NativeResponse(incoming.uri!, incoming.headers.protocolVersion, outgoing,
          server.defaultResponseHeaders, server.serverHeader);
      // Parser found badRequest and sent out Response.
      if (incoming.statusCode == HttpStatus.badRequest) {
        response.statusCode = HttpStatus.badRequest;
      }

      var request = NativeRequest(response, incoming, server, this);
      streamFuture = outgoing.done.then((_) {
        response.deadline = null;
        if (state == detached) return;
        if (response.persistentConnection &&
            request.persistentConnection &&
            incoming.fullBodyRead &&
            !parser.upgrade &&
            !server.closed) {
          state = idle;
          idleMark = false;
          server._markIdle(this);
          // Resume the subscription for incoming requests as the
          // request is now processed.
          subscription!.resume();
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
      server._handleRequest(request);
    }, onDone: () {
      destroy();
    }, onError: (error) {
      // Ignore failed requests that was closed before headers was received.
      destroy();
    });
  }

  void markIdle() {
    idleMark = true;
  }

  bool get isMarkedIdle => idleMark;

  void destroy() {
    if (state == closing || state == detached) return;
    state = closing;
    socket.destroy();
    server._connectionClosed(this);
    connections.remove(serviceId);
  }

  Future<Socket> detachSocket() {
    state = detached;
    // Remove connection from server.
    server._connectionClosed(this);

    DetachedIncoming detachedIncoming = parser.detachIncoming();

    return streamFuture!.then((_) {
      connections.remove(serviceId);
      return _DetachedSocket(socket, detachedIncoming);
    });
  }

  bool get _isActive => state == active;
  bool get _isIdle => state == idle;
  bool get _isClosing => state == closing;
  bool get _isDetached => state == detached;
}

// HTTP server waiting for socket connections.
class NativeServer extends Stream<AstraRequest> with ServiceObject implements AstraServer {
  // Use default Map so we keep order.
  static final Map<int, NativeServer> _servers = <int, NativeServer>{};

  @override
  String? serverHeader;
  @override
  final AstraHeaders defaultResponseHeaders = _initDefaultResponseHeaders();
  @override
  bool autoCompress = false;

  Duration? _idleTimeout;
  Timer? _idleTimer;

  static Future<AstraServer> bind(Object address, int port, int backlog, bool v6Only, bool shared) {
    return ServerSocket.bind(address, port, backlog: backlog, v6Only: v6Only, shared: shared)
        .then<AstraServer>((socket) {
      return NativeServer._(socket, true);
    });
  }

  NativeServer._(this._serverSocket, this._closeServer) : _controller = StreamController<AstraRequest>(sync: true) {
    _controller.onCancel = close;
    idleTimeout = const Duration(seconds: 120);
    _servers[serviceId] = this;
  }

  NativeServer.listenOn(this._serverSocket)
      : _closeServer = false,
        _controller = StreamController<AstraRequest>(sync: true) {
    _controller.onCancel = close;
    idleTimeout = const Duration(seconds: 120);
    _servers[serviceId] = this;
  }

  static AstraHeaders _initDefaultResponseHeaders() {
    var defaultResponseHeaders = NativeHeaders('1.1');
    defaultResponseHeaders.contentType = ContentType.text;
    defaultResponseHeaders.set('X-Frame-Options', 'SAMEORIGIN');
    defaultResponseHeaders.set('X-Content-Type-Options', 'nosniff');
    defaultResponseHeaders.set('X-XSS-Protection', '1; mode=block');
    return defaultResponseHeaders;
  }

  @override
  Duration? get idleTimeout => _idleTimeout;

  @override
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
  StreamSubscription<AstraRequest> listen(void Function(AstraRequest event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _serverSocket.listen((Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }
      // Accept the client connection.
      Connection connection = Connection(socket, this);
      _idleConnections.add(connection);
    }, onError: (Object error, StackTrace? stackTrace) {
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
      result = _serverSocket.close();
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
    if (closed) throw HttpException('HttpServer is not bound to a socket');
    return _serverSocket.port;
  }

  @override
  InternetAddress get address {
    if (closed) throw HttpException('HttpServer is not bound to a socket');
    return _serverSocket.address;
  }

  void _handleRequest(NativeRequest request) {
    if (!closed) {
      _controller.add(request);
    } else {
      request.connection.destroy();
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

  void markActive(Connection connection) {
    _idleConnections.remove(connection);
    _activeConnections.add(connection);
  }

  // Indicated if the http server has been closed.
  bool closed = false;

  // The server listen socket. Untyped as it can be both ServerSocket and
  // SecureServerSocket.
  final ServerSocket _serverSocket;
  final bool _closeServer;

  // Set of currently connected clients.
  final LinkedList<Connection> _activeConnections = LinkedList<Connection>();
  final LinkedList<Connection> _idleConnections = LinkedList<Connection>();
  final StreamController<AstraRequest> _controller;
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
  void writeAll(Iterable objects, [String separator = '']) {
    _socket.writeAll(objects, separator);
  }

  @override
  void add(List<int> bytes) {
    _socket.add(bytes);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _socket.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) {
    return _socket.addStream(stream);
  }

  @override
  void destroy() {
    _socket.destroy();
  }

  @override
  Future flush() => _socket.flush();

  @override
  Future close() => _socket.close();

  @override
  Future get done => _socket.done;

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
