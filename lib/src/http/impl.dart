// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection' show HashMap, LinkedList, LinkedListEntry;
import 'dart:convert' show ByteConversionSink, Encoding, latin1;
import 'dart:io'
    show
        ContentType,
        HandshakeException,
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
import 'package:meta/meta.dart';

abstract class ServiceObject {
  static int nextServiceId = 1;

  final int serviceId = nextServiceId += 1;
}

class CopyingBytesBuilder implements BytesBuilder {
  static const int initSize = 1024;

  static final Uint8List emptyList = Uint8List(0);

  CopyingBytesBuilder([int initialCapacity = 0])
      : buffer = initialCapacity <= 0 ? emptyList : Uint8List(pow2roundup(initialCapacity));

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

    if (bytesLength == 0) {
      return;
    }

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
    int newSize = required * 2;

    if (newSize < initSize) {
      newSize = initSize;
    } else {
      newSize = pow2roundup(newSize);
    }

    Uint8List newBuffer = Uint8List(newSize);
    newBuffer.setRange(0, buffer.length, buffer);
    buffer = newBuffer;
  }

  @override
  Uint8List takeBytes() {
    if (length == 0) {
      return emptyList;
    }

    Uint8List bytes = Uint8List.view(buffer.buffer, buffer.offsetInBytes, length);
    clear();
    return bytes;
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

  static int pow2roundup(int x) {
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

  final Completer<bool> dataCompleter = Completer<bool>();

  bool hasSubscriber = false;

  bool fullBodyRead = false;

  bool upgraded = false;

  int? statusCode;

  String? reasonPhrase;

  String? method;

  Uri? uri;

  Future<bool> get dataDone {
    return dataCompleter.future;
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    hasSubscriber = true;

    void handleError(Object error) {
      throw HttpException((error as dynamic).message as String, uri: uri);
    }

    return stream.handleError(handleError).listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }

  void close(bool closing) {
    fullBodyRead = true;
    hasSubscriber = true;
    dataCompleter.complete(closing);
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

class NativeRequest extends InboundMessage {
  NativeRequest(this.server, this.connection, this.response, Incoming incoming) : super(incoming) {
    if (headers.protocolVersion == '1.1') {
      response.headers
        ..chunkedTransferEncoding = true
        ..persistentConnection = headers.persistentConnection;
    }
  }

  final NativeServer server;

  final Connection connection;

  final NativeResponse response;

  Uri? parsedRequestedUri;

  String get method {
    return incoming.method!;
  }

  Uri get uri {
    return incoming.uri!;
  }

  Uri get requestedUri {
    Uri? requestedUri = parsedRequestedUri;

    if (requestedUri != null) {
      return requestedUri;
    }

    List<String>? proto = headers['x-forwarded-proto'];
    String scheme;

    if (proto == null) {
      scheme = connection.socket is SecureSocket ? 'https' : 'http';
    } else {
      scheme = proto.first;
    }

    List<String>? hostList = headers['x-forwarded-host'];
    String host;

    if (hostList == null) {
      hostList = headers[HttpHeaders.hostHeader];

      if (hostList == null) {
        host = '${server.address.host}:${server.port}';
      } else {
        host = hostList.first;
      }
    } else {
      host = hostList.first;
    }

    return parsedRequestedUri = Uri.parse('$scheme://$host$uri');
  }

  HttpConnectionInfo? get connectionInfo {
    return connection.connectionInfo;
  }

  X509Certificate? get certificate {
    Socket socket = connection.socket;

    if (socket is SecureSocket) {
      return socket.peerCertificate;
    }

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

class StreamSinkBase<T> implements StreamSink<T> {
  StreamSinkBase(this.target);

  final StreamConsumer<T> target;

  final Completer<void> doneCompleter = Completer<void>();

  StreamController<T>? controllerInstance;

  Completer<void>? controllerCompleter;

  bool isClosed = false;

  bool isBound = false;

  bool hasError = false;

  @override
  Future<void> get done {
    return doneCompleter.future;
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

      void onDone(Object? value) {
        if (isBound) {
          // A new stream takes over - forward values to that stream.
          // ignore: void_checks
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

    StreamController<T>? controller = controllerInstance;

    if (controller == null) {
      return targetAddStream();
    }

    Future<void> future = controllerCompleter!.future;
    controller.close();

    Future<void> onDone(Object? result) {
      return targetAddStream();
    }

    return future.then<void>(onDone);
  }

  Future<void> flush() {
    if (isBound) {
      throw StateError('StreamSink is bound to a stream');
    }

    StreamController<T>? controller = controllerInstance;

    if (controller == null) {
      // ignore: void_checks
      return Future<void>.value(this);
    }

    // Adding an empty stream-controller will return a future that will complete
    // when all data is done.
    isBound = true;

    Future<void> future = controllerCompleter!.future;
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

      StreamController<T>? controller = controllerInstance;

      if (controller != null) {
        controller.close();
      } else {
        closeTarget();
      }
    }

    return done;
  }

  void completeDoneValue(Object? value) {
    if (doneCompleter.isCompleted) {
      return;
    }

    // ignore: void_checks
    doneCompleter.complete(value);
  }

  void completeDoneError(Object error, StackTrace stackTrace) {
    if (doneCompleter.isCompleted) {
      return;
    }

    hasError = true;
    doneCompleter.completeError(error, stackTrace);
  }

  void closeTarget() {
    target.close().then<void>(completeDoneValue, onError: completeDoneError);
  }
}

class IOSinkBase extends StreamSinkBase<List<int>> implements IOSink {
  IOSinkBase(StreamConsumer<List<int>> target, this.currentEncoding) : super(target);

  Encoding currentEncoding;

  bool encodingMutable = true;

  @override
  Encoding get encoding {
    return currentEncoding;
  }

  @override
  set encoding(Encoding value) {
    if (!encodingMutable) {
      throw StateError('IOSink encoding is not mutable');
    }

    currentEncoding = value;
  }

  @override
  void write(Object? object) {
    String string = '$object';

    if (string.isEmpty) {
      return;
    }

    super.add(currentEncoding.encode(string));
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    Iterator<Object?> iterator = objects.iterator;

    if (!iterator.moveNext()) {
      return;
    }

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

@optionalTypeArgs
abstract class OutboundMessage<T> extends IOSinkBase {
  OutboundMessage(this.uri, this.outgoing, String protocolVersion, {NativeHeaders? initialHeaders})
      : headers = NativeHeaders(protocolVersion,
            defaultPortForScheme: uri.isScheme('https') ? 433 : 80, initialHeaders: initialHeaders),
        super(outgoing, latin1) {
    outgoing.outbound = this;
    encodingMutable = false;
  }

  final Uri uri;

  final Outgoing outgoing;

  final NativeHeaders headers;

  // Used to mark when the body should be written.
  // This is used for HEAD requests and in error handling.
  bool encodingSet = false;

  bool buffer = true;

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
    if (outgoing.headersWritten) {
      throw StateError('Header already sent');
    }

    buffer = bufferOutput;
  }

  @override
  Encoding get encoding {
    if (encodingSet && outgoing.headersWritten) {
      return currentEncoding;
    }

    ContentType? contentType = headers.contentType;
    String charset;

    if (contentType != null && contentType.charset != null) {
      charset = contentType.charset!;
    } else {
      charset = 'iso-8859-1';
    }

    return Encoding.getByName(charset) ?? latin1;
  }

  bool get isConnectionClosed {
    return false;
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
      currentEncoding = encoding;
      encodingSet = true;
    }

    super.write(object);
  }

  void writeHeader();
}

class NativeResponse extends OutboundMessage<NativeResponse> {
  NativeResponse(Uri uri, String protocolVersion, Outgoing outgoing, NativeHeaders defaultHeaders)
      : super(uri, outgoing, protocolVersion, initialHeaders: defaultHeaders);

  int _statusCode = 200;
  String? currentReasonPhrase;
  NativeRequest? request;
  Duration? _deadline;
  Timer? _deadlineTimer;

  @override
  bool get isConnectionClosed {
    return request!.connection.isClosing;
  }

  int get statusCode {
    return _statusCode;
  }

  set statusCode(int statusCode) {
    if (outgoing.headersWritten) {
      throw StateError('Header already sent');
    }

    _statusCode = statusCode;
  }

  String get reasonPhrase {
    return currentReasonPhrase ??= findReasonPhrase(statusCode);
  }

  set reasonPhrase(String reasonPhrase) {
    if (outgoing.headersWritten) {
      throw StateError('Header already sent');
    }
    currentReasonPhrase = reasonPhrase;
  }

  Future<void> redirect(Uri location, {int status = HttpStatus.movedTemporarily}) {
    if (outgoing.headersWritten) throw StateError('Header already sent');
    statusCode = status;
    headers.set(HttpHeaders.locationHeader, location.toString());
    return close();
  }

  Future<Socket> detachSocket({bool writeHeaders = true}) {
    if (outgoing.headersWritten) throw StateError('Headers already sent');
    deadline = null; // Be sure to stop any deadline.
    var future = request!.connection.detachSocket();
    if (writeHeaders) {
      var headersFuture = outgoing.writeHeaders(drainRequest: false, setOutgoing: false);
      assert(headersFuture == null);
    } else {
      // Imitate having written the headers.
      outgoing.headersWritten = true;
    }
    // Close connection so the socket is 'free'.
    close();
    done.catchError((_) {
      // Catch any error on done, as they automatically will be
      // propagated to the websocket.
    });
    return future;
  }

  HttpConnectionInfo? get connectionInfo => request!.connectionInfo;

  Duration? get deadline => _deadline;

  set deadline(Duration? d) {
    _deadlineTimer?.cancel();
    _deadline = d;

    if (d == null) return;
    _deadlineTimer = Timer(d, () {
      request!.connection.destroy();
    });
  }

  @override
  void writeHeader() {
    BytesBuilder buffer = CopyingBytesBuilder(outgoingBufferSize);

    // Write status line.
    if (headers.protocolVersion == '1.1') {
      buffer.add(Const.http11);
    } else {
      buffer.add(Const.http10);
    }

    buffer
      ..addByte(CharCode.sp)
      ..add('$statusCode'.codeUnits)
      ..addByte(CharCode.sp)
      ..add(reasonPhrase.codeUnits)
      ..addByte(CharCode.cr)
      ..addByte(CharCode.lf);

    headers.build(buffer);

    buffer
      ..addByte(CharCode.cr)
      ..addByte(CharCode.lf);

    Uint8List headerBytes = buffer.takeBytes();
    outgoing.setHeader(headerBytes, headerBytes.length);
  }

  static String findReasonPhrase(int statusCode) {
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
class GZipSink extends ByteConversionSink {
  GZipSink(this.consume);

  final BytesConsumer consume;

  @override
  void add(List<int> chunk) {
    consume(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    if (chunk is Uint8List) {
      consume(Uint8List.view(chunk.buffer, chunk.offsetInBytes + start, end - start));
    } else {
      consume(chunk.sublist(start, end - start));
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
// one before gzip (this._gzipBuffer) and one after (_buffer).
class Outgoing implements StreamConsumer<List<int>> {
  static const List<int> footerAndChunk0Length = <int>[
    CharCode.cr, CharCode.lf, //
    0x30, //
    CharCode.cr, CharCode.lf, CharCode.cr, CharCode.lf
  ];

  static const List<int> chunk0Length = <int>[
    0x30, //
    CharCode.cr, CharCode.lf, CharCode.cr, CharCode.lf
  ];

  Outgoing(this.socket);

  final Socket socket;

  final Completer<Socket> doneCompleter = Completer<Socket>();

  bool ignoreBody = false;

  bool headersWritten = false;

  Uint8List? bufferedData;

  int bufferDataLength = 0;

  Future<void>? closeFuture;

  bool chunked = false;

  int pendingChunkedFooter = 0;

  int? contentLength;

  int bytesWritten = 0;

  bool gzipState = false;

  ByteConversionSink? gzipSink;

  // _gzipAdd is set iff the sink is being added to. It's used to specify where
  // gzipped data should be taken (sometimes a controller, sometimes a socket).
  BytesConsumer? gzipAdd;

  Uint8List? gzipBuffer;

  int gzipBufferLength = 0;

  bool socketError = false;

  OutboundMessage? outbound;

  Future<Socket> get done {
    return doneCompleter.future;
  }

  set gzip(bool value) {
    gzipState = value;

    if (value) {
      gzipBuffer = Uint8List(outgoingBufferSize);
      assert(gzipSink == null);
      gzipSink = ZLibEncoder(gzip: true).startChunkedConversion(GZipSink((data) {
        // We are closing down prematurely, due to an error. Discard.
        if (gzipAdd == null) return;
        addChunk(chunkHeader(data.length), gzipAdd!);
        pendingChunkedFooter = 2;
        addChunk(data, gzipAdd!);
      }));
    }
  }

  // Returns either a future or 'null', if it was able to write headers
  // immediately.
  Future<void>? writeHeaders({bool drainRequest = true, bool setOutgoing = true}) {
    if (headersWritten) {
      return null;
    }

    headersWritten = true;

    Future<void>? drainFuture;
    bool gzip = false;
    OutboundMessage response = outbound!;

    if (response is NativeResponse) {
      // Server side.
      if (response.request!.server.autoCompress && response.bufferOutput && response.headers.chunkedTransferEncoding) {
        List<String>? acceptEncodings = response.request!.headers[HttpHeaders.acceptEncodingHeader];
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

      if (drainRequest && !response.request!.incoming.hasSubscriber) {
        void onError(Object error) {
          // pass
        }

        drainFuture = response.request!.drain<void>().catchError(onError);
      }
    } else {
      drainRequest = false;
    }

    if (!ignoreBody) {
      if (setOutgoing) {
        int contentLength = response.headers.contentLength;

        if (response.headers.chunkedTransferEncoding) {
          chunked = true;

          if (gzip) {
            this.gzip = true;
          }
        } else if (contentLength >= 0) {
          this.contentLength = contentLength;
        }
      }

      if (drainFuture != null) {
        void onDone(Object? value) {
          return response.writeHeader();
        }

        return drainFuture.then<void>(onDone);
      }
    }

    response.writeHeader();
    return null;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    if (socketError) {
      stream.listen(null).cancel();
      // ignore: void_checks
      return Future<void>.value(outbound);
    }

    if (ignoreBody) {
      void onError(Object error) {
        // pass
      }

      stream.drain<void>().catchError(onError);

      Future<void>? future = writeHeaders();

      if (future == null) {
        return close();
      }

      Future<void> onDone(Object? value) {
        return close();
      }

      return future.then<void>(onDone);
    }

    // Use new stream so we are able to pause (see below listen). The
    // alternative is to use stream.extand, but that won't give us a way of
    // pausing.
    StreamController<List<int>> controller = StreamController<List<int>>(sync: true);

    void onData(List<int> data) {
      if (socketError) {
        return;
      }

      if (data.isEmpty) {
        return;
      }

      if (chunked) {
        if (gzipState) {
          gzipAdd = controller.add;
          addGZipChunk(data, gzipSink!.add);
          gzipAdd = null;
          return;
        }

        addChunk(chunkHeader(data.length), controller.add);
        pendingChunkedFooter = 2;
      } else {
        int? contentLength = this.contentLength;

        if (contentLength != null) {
          bytesWritten += data.length;

          if (bytesWritten > contentLength) {
            controller.addError(HttpException('Content size exceeds specified contentLength. '
                '$bytesWritten bytes written while expected $contentLength. '
                '[${String.fromCharCodes(data)}]'));
            return;
          }
        }
      }

      addChunk(data, controller.add);
    }

    StreamSubscription<List<int>> subscription = stream.listen(onData, //
        onError: controller.addError,
        onDone: controller.close,
        cancelOnError: true);

    controller
      ..onPause = subscription.pause
      ..onResume = subscription.resume;

    // Write headers now that we are listening to the stream.
    if (!headersWritten) {
      Future<void>? future = writeHeaders();

      if (future != null) {
        // While incoming is being drained, the pauseFuture is non-null. Pause
        // output until it's drained.
        subscription.pause(future);
      }
    }

    OutboundMessage? onDone(Object? value) {
      return outbound;
    }

    OutboundMessage? onError(Object error, [StackTrace? stackTrace]) {
      // Be sure to close it in case of an error.
      if (gzipState) {
        gzipSink!.close();
      }

      socketError = true;
      doneCompleter.completeError(error, stackTrace);

      if (ignoreError(error)) {
        return outbound;
      }

      throw error;
    }

    return socket.addStream(controller.stream).then(onDone, onError: onError);
  }

  @override
  Future<void> close() {
    // If we are already closed, return that future.
    var closeFuture = this.closeFuture;

    if (closeFuture != null) {
      return closeFuture;
    }

    var outbound = this.outbound!;

    // If we earlier saw an error, return immediate. The notification to
    // _Http*Connection is already done.
    if (socketError) {
      // ignore: void_checks
      return Future<void>.value(outbound);
    }

    if (outbound.isConnectionClosed) {
      // ignore: void_checks
      return Future<void>.value(outbound);
    }

    if (!headersWritten && !ignoreBody) {
      if (outbound.headers.contentLength == -1) {
        // If no body was written, ignoreBody is false (it's not a HEAD
        // request) and the content-length is unspecified, set contentLength to
        // 0.
        outbound.headers
          ..chunkedTransferEncoding = false
          ..contentLength = 0;
      } else if (outbound.headers.contentLength > 0) {
        HttpException error = HttpException(
            'No content even though contentLength was specified to be '
            'greater than 0: ${outbound.headers.contentLength}.',
            uri: outbound.uri);
        doneCompleter.completeError(error);
        return this.closeFuture = Future<void>.error(error);
      }
    }
    // If contentLength was specified, validate it.
    int? contentLength = this.contentLength;

    if (contentLength != null) {
      if (bytesWritten < contentLength) {
        HttpException error = HttpException(
            'Content size below specified contentLength. '
            '$bytesWritten bytes written but expected $contentLength.',
            uri: outbound.uri);
        doneCompleter.completeError(error);
        return this.closeFuture = Future<void>.error(error);
      }
    }

    Future<void> finalize() {
      // In case of chunked encoding (and gzip), handle remaining gzip data and
      // append the 'footer' for chunked encoding.
      if (chunked) {
        if (gzipState) {
          gzipAdd = socket.add;

          if (gzipBufferLength > 0) {
            gzipSink!.add(Uint8List.view(gzipBuffer!.buffer, gzipBuffer!.offsetInBytes, gzipBufferLength));
          }

          gzipBuffer = null;
          gzipSink!.close();
          gzipAdd = null;
        }

        addChunk(chunkHeader(0), socket.add);
      }

      // Add any remaining data in the buffer.
      if (bufferDataLength > 0) {
        socket.add(Uint8List.view(bufferedData!.buffer, bufferedData!.offsetInBytes, bufferDataLength));
      }

      // Clear references, for better GC.
      bufferedData = null;

      OutboundMessage onData(Object? value) {
        doneCompleter.complete(socket);
        return outbound;
      }

      OutboundMessage onError(Object error, [StackTrace? stackTrace]) {
        doneCompleter.completeError(error, stackTrace);

        if (ignoreError(error)) {
          return outbound;
        }

        throw error;
      }

      // And finally flush it. As we support keep-alive, never close it from
      // here. Once the socket is flushed, we'll be able to reuse it (signaled
      // by the 'done' future).
      return socket.flush().then<void>(onData, onError: onError);
    }

    Future<void>? future = writeHeaders();

    if (future == null) {
      return this.closeFuture = finalize();
    }

    return this.closeFuture = future.whenComplete(finalize);
  }

  void setHeader(List<int> data, int length) {
    assert(bufferDataLength == 0);
    bufferedData = data as Uint8List;
    bufferDataLength = length;
  }

  bool ignoreError(Object error) {
    return (error is SocketException || error is TlsException) && outbound is NativeResponse;
  }

  void addGZipChunk(List<int> chunk, void Function(List<int> data) add) {
    bool bufferOutput = outbound!.bufferOutput;

    if (!bufferOutput) {
      add(chunk);
      return;
    }

    Uint8List gzipBuffer = this.gzipBuffer!;

    if (chunk.length > gzipBuffer.length - gzipBufferLength) {
      add(Uint8List.view(gzipBuffer.buffer, gzipBuffer.offsetInBytes, gzipBufferLength));
      this.gzipBuffer = Uint8List(outgoingBufferSize);
      gzipBufferLength = 0;
    }

    if (chunk.length > outgoingBufferSize) {
      add(chunk);
    } else {
      int currentLength = gzipBufferLength;
      int newLength = currentLength + chunk.length;
      this.gzipBuffer!.setRange(currentLength, newLength, chunk);
      gzipBufferLength = newLength;
    }
  }

  void addChunk(List<int> chunk, void Function(List<int> data) add) {
    var bufferOutput = outbound!.bufferOutput;

    if (!bufferOutput) {
      if (bufferedData != null) {
        // If buffer is not null, we have not written the header yet. Write it now.
        add(Uint8List.view(bufferedData!.buffer, bufferedData!.offsetInBytes, bufferDataLength));
        bufferedData = null;
        bufferDataLength = 0;
      }

      add(chunk);
      return;
    }

    if (chunk.length > bufferedData!.length - bufferDataLength) {
      add(Uint8List.view(bufferedData!.buffer, bufferedData!.offsetInBytes, bufferDataLength));
      bufferedData = Uint8List(outgoingBufferSize);
      bufferDataLength = 0;
    }

    if (chunk.length > outgoingBufferSize) {
      add(chunk);
    } else {
      bufferedData!.setRange(bufferDataLength, bufferDataLength + chunk.length, chunk);
      bufferDataLength += chunk.length;
    }
  }

  List<int> chunkHeader(int length) {
    const hexDigits = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46];

    if (length == 0) {
      if (pendingChunkedFooter == 2) {
        return footerAndChunk0Length;
      }

      return chunk0Length;
    }

    int size = pendingChunkedFooter;
    int len = length;

    while (len > 0) {
      size += 1;
      len >>= 4;
    }

    Uint8List footerAndHeader = Uint8List(size + 2);

    if (pendingChunkedFooter == 2) {
      footerAndHeader[0] = CharCode.cr;
      footerAndHeader[1] = CharCode.lf;
    }

    int index = size;

    while (index > pendingChunkedFooter) {
      footerAndHeader[index -= 1] = hexDigits[length & 15];
      length = length >> 4;
    }

    footerAndHeader
      ..[size + 0] = CharCode.cr
      ..[size + 1] = CharCode.lf;

    return footerAndHeader;
  }
}

class Connection extends LinkedListEntry<Connection> with ServiceObject {
  static const int active = 0, idle = 1, closing = 2, detached = 3;

  // Use HashMap, as we don't need to keep order.
  static final Map<int, Connection> connections = HashMap<int, Connection>();

  Connection(this.socket, this.server) : parser = Parser.requestParser() {
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
      var response =
          NativeResponse(incoming.uri!, incoming.headers.protocolVersion, outgoing, server.defaultResponseHeaders);
      // Parser found badRequest and sent out Response.
      if (incoming.statusCode == HttpStatus.badRequest) {
        response.statusCode = HttpStatus.badRequest;
      }
      var request = NativeRequest(server, this, response, incoming);
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
          server.markIdle(this);
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
      response.request = request;
      server.handleRequest(request);
    }, onDone: () {
      destroy();
    }, onError: (error) {
      // Ignore failed requests that was closed before headers was received.
      destroy();
    });
  }

  final Socket socket;

  final NativeServer server;

  final Parser parser;

  int state = idle;

  bool idleMark = false;

  StreamSubscription<void>? subscription;

  Future<void>? streamFuture;

  bool get isMarkedIdle {
    return idleMark;
  }

  bool get isActive {
    return state == active;
  }

  bool get isIdle {
    return state == idle;
  }

  bool get isClosing {
    return state == closing;
  }

  bool get isDetached {
    return state == detached;
  }

  HttpConnectionInfo? get connectionInfo {
    return ConnectionInfo.create(socket);
  }

  void markIdle() {
    idleMark = true;
  }

  void destroy() {
    if (state == closing || state == detached) {
      return;
    }

    state = closing;
    socket.destroy();
    server.connectionClosed(this);
    connections.remove(serviceId);
  }

  Future<Socket> detachSocket() {
    state = detached;

    // Remove connection from server.
    server.connectionClosed(this);

    DetachedIncoming detachedIncoming = parser.detachIncoming();

    DetachedSocket onDone(Object? value) {
      connections.remove(serviceId);
      return DetachedSocket(socket, detachedIncoming);
    }

    return streamFuture!.then<Socket>(onDone);
  }
}

// HTTP server waiting for socket connections.
class NativeServer extends Stream<NativeRequest> {
  NativeServer.listenOn(Stream<Socket> serverSocket, {Duration idleTimeout = const Duration(seconds: 120)})
      : this(serverSocket, closeServer: false, idleTimeout: idleTimeout);

  NativeServer(this.serverSocket, {this.closeServer = true, Duration idleTimeout = const Duration(seconds: 120)})
      : controller = StreamController<NativeRequest>(sync: true) {
    controller.onCancel = close;

    void onTick(Timer timer) {
      for (Connection connection in idle.toList()) {
        if (connection.isMarkedIdle) {
          connection.destroy();
        } else {
          connection.markIdle();
        }
      }
    }

    idleTimer = Timer.periodic(idleTimeout, onTick);
  }

  final Stream<Socket> serverSocket;

  final bool closeServer;

  final StreamController<NativeRequest> controller;

  final NativeHeaders defaultResponseHeaders = initDefaultResponseHeaders();

  final LinkedList<Connection> active = LinkedList<Connection>();

  final LinkedList<Connection> idle = LinkedList<Connection>();

  bool autoCompress = false;

  bool closed = false;

  Timer? idleTimer;

  InternetAddress get address {
    if (closed) {
      throw HttpException('NativeServer is not bound to a socket');
    }

    return (serverSocket as dynamic).address as InternetAddress;
  }

  int get port {
    if (closed) {
      throw HttpException('NativeServer is not bound to a socket');
    }

    return (serverSocket as dynamic).port as int;
  }

  void handleRequest(NativeRequest request) {
    if (closed) {
      request.connection.destroy();
    } else {
      controller.add(request);
    }
  }

  void connectionClosed(Connection connection) {
    // Remove itself from either idle or active connections.
    connection.unlink();
  }

  void markIdle(Connection connection) {
    active.remove(connection);
    idle.add(connection);
  }

  void markActive(Connection connection) {
    idle.remove(connection);
    active.add(connection);
  }

  HttpConnectionsInfo connectionsInfo() {
    HttpConnectionsInfo result = HttpConnectionsInfo();
    result.total = active.length + idle.length;

    for (Connection connection in active) {
      if (connection.isActive) {
        result.active += 1;
      } else {
        assert(connection.isClosing);
        result.closing += 1;
      }
    }

    for (Connection connection in idle) {
      result.idle += 1;
      assert(connection.isIdle);
    }

    return result;
  }

  @override
  StreamSubscription<NativeRequest> listen(void Function(NativeRequest event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    void onSocket(Socket socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }

      // Accept the client connection.
      idle.add(Connection(socket, this));
    }

    void onError(Object error, [StackTrace? stackTrace]) {
      // Ignore HandshakeExceptions as they are bound to a single request,
      // and are not fatal for the server.
      if (error is! HandshakeException) {
        controller.addError(error, stackTrace);
      }
    }

    serverSocket.listen(onSocket, //
        onError: onError,
        onDone: controller.close);
    return controller.stream.listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }

  Future<void> close({bool force = false}) {
    closed = true;

    Future<void> result;

    if (closeServer) {
      result = (serverSocket as dynamic).close() as Future<void>;
    } else {
      result = Future<void>.value();
    }

    Timer? idleTimer = this.idleTimer;

    if (idleTimer != null) {
      idleTimer.cancel();
      this.idleTimer = null;
    }

    if (force) {
      for (Connection connection in active.toList()) {
        connection.destroy();
      }

      assert(active.isEmpty);
    }

    for (Connection connection in idle.toList()) {
      connection.destroy();
    }

    return result;
  }

  static NativeHeaders initDefaultResponseHeaders() {
    var defaultResponseHeaders = NativeHeaders('1.1');
    defaultResponseHeaders.set('Content-Type', 'text/plain; charset=utf-8');
    defaultResponseHeaders.set('X-Frame-Options', 'SAMEORIGIN');
    defaultResponseHeaders.set('X-Content-Type-Options', 'nosniff');
    defaultResponseHeaders.set('X-XSS-Protection', '1; mode=block');
    return defaultResponseHeaders;
  }

  static Future<NativeServer> bind(Object address, int port, //
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false}) {
    return ServerSocket.bind(address, port, //
            backlog: backlog,
            v6Only: v6Only,
            shared: shared)
        .then<NativeServer>(NativeServer.new);
  }

  static Future<NativeServer> bindSecure(Object address, int port, SecurityContext? context, //
      {int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false}) {
    return SecureServerSocket.bind(address, port, context, //
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            shared: shared)
        .then<NativeServer>(NativeServer.new);
  }
}

class ConnectionInfo implements HttpConnectionInfo {
  ConnectionInfo(this.remoteAddress, this.remotePort, this.localPort);

  @override
  InternetAddress remoteAddress;

  @override
  int remotePort;

  @override
  int localPort;

  static ConnectionInfo? create(Socket socket) {
    try {
      return ConnectionInfo(socket.remoteAddress, socket.remotePort, socket.port);
    } catch (error) {
      // pass
    }

    return null;
  }
}

class DetachedSocket extends Stream<Uint8List> implements Socket {
  DetachedSocket(this.socket, this.incoming);

  final Stream<Uint8List> incoming;

  final Socket socket;

  @override
  Encoding get encoding {
    return socket.encoding;
  }

  @override
  set encoding(Encoding value) {
    socket.encoding = value;
  }

  @override
  InternetAddress get address {
    return socket.address;
  }

  @override
  int get port {
    return socket.port;
  }

  @override
  InternetAddress get remoteAddress {
    return socket.remoteAddress;
  }

  @override
  int get remotePort {
    return socket.remotePort;
  }

  @override
  Future<void> get done {
    return socket.done;
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

  @override
  bool setOption(SocketOption option, bool enabled) {
    return socket.setOption(option, enabled);
  }

  @override
  Uint8List getRawOption(RawSocketOption option) {
    return socket.getRawOption(option);
  }

  @override
  void setRawOption(RawSocketOption option) {
    socket.setRawOption(option);
  }

  @override
  void add(List<int> bytes) {
    socket.add(bytes);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    return socket.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return socket.addStream(stream);
  }

  @override
  void write(Object? object) {
    socket.write(object);
  }

  @override
  void writeln([Object? object = '']) {
    socket.writeln(object);
  }

  @override
  void writeCharCode(int charCode) {
    socket.writeCharCode(charCode);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    socket.writeAll(objects, separator);
  }

  @override
  void destroy() {
    socket.destroy();
  }

  @override
  Future<void> flush() {
    return socket.flush();
  }

  @override
  Future<void> close() {
    return socket.close();
  }
}
