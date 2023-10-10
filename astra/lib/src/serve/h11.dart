import 'dart:async' show Completer, FutureOr;
import 'dart:io'
    show
        HttpHeaders,
        HttpRequest,
        HttpResponse,
        HttpServer,
        InternetAddress,
        InternetAddressType,
        SecurityContext,
        Socket;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/error.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
import 'package:astra/src/serve/server.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:collection/collection.dart' show equalsIgnoreAsciiCase;
import 'package:http_parser/http_parser.dart' show chunkedCoding;
import 'package:stream_channel/stream_channel.dart' show StreamChannel;

/// A HTTP/1.1 [Server] backed by a `dart:io` [HttpServer].
class ShelfServer implements Server {
  ShelfServer(HttpServer httpServer, {bool isSecure = false})
      : _httpServer = httpServer,
        _isSecure = isSecure,
        _doneCompleter = Completer<void>();

  final HttpServer _httpServer;

  final bool _isSecure;

  final Completer<void> _doneCompleter;

  Application? _application;

  @override
  Application? get application {
    return _application;
  }

  @override
  InternetAddress get address {
    return _httpServer.address;
  }

  @override
  int get port {
    return _httpServer.port;
  }

  @override
  Uri get url {
    String host;

    if (address.isLoopback) {
      host = 'localhost';
    } else if (address.type == InternetAddressType.IPv6) {
      host = '[${address.address}]';
    } else {
      host = address.address;
    }

    return Uri(scheme: _isSecure ? 'https' : 'http', host: host, port: port);
  }

  @override
  Future<void> get done {
    return _doneCompleter.future;
  }

  @override
  Future<void> mount(Application application) async {
    if (_application != null) {
      throw StateError("Can't mount two handlers for the same server");
    }

    _application = application;
    await application.prepare();

    var handler = application.entryPoint;

    void onRequest(HttpRequest request) {
      handleRequest(handler, request);
    }

    void body() {
      _httpServer.listen(onRequest);
    }

    void onError(Object error, StackTrace stackTrace) {
      logError('Asynchronous error\n$error', stackTrace);
    }

    catchTopLevelErrors(body, onError);
  }

  @override
  Future<void> close({bool force = false}) async {
    if (_doneCompleter.isCompleted) {
      return;
    }

    try {
      await _httpServer.close(force: force);

      if (application case var application?) {
        await application.close();
      }
    } finally {
      _doneCompleter.complete();
    }
  }

  /// Bounds the [ShelfServer] to the given [address] and [port].
  static Future<ShelfServer> bind(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool v6Only = false,
    bool requestClientCertificate = false,
    bool shared = false,
  }) async {
    var isSecure = securityContext != null;
    HttpServer server;

    if (isSecure) {
      server = await HttpServer.bindSecure(address, port, securityContext,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared);
    } else {
      server = await HttpServer.bind(address, port,
          backlog: backlog, v6Only: v6Only, shared: shared);
    }

    return ShelfServer(server, isSecure: isSecure);
  }
}

/// Uses [Handler] to handle [HttpRequest].
// TODO(h11): error response with message
Future<void> handleRequest(
  FutureOr<Response?> Function(Request) handler,
  HttpRequest httpRequest,
) async {
  Request request;

  try {
    request = fromHttpRequest(httpRequest);
  } on ArgumentError catch (error, stackTrace) {
    if (error.name == 'method' || error.name == 'requestedUri') {
      logError('Error parsing request\n$error', stackTrace);

      var response = Response.badRequest(body: 'Bad Request');
      await writeResponse(response, httpRequest.response);
    } else {
      logError('Error parsing request\n$error', stackTrace);

      var response = Response.internalServerError();
      await writeResponse(response, httpRequest.response);
    }

    return;
  } catch (error, stackTrace) {
    logError('Error parsing request\n$error', stackTrace);

    var response = Response.internalServerError();
    await writeResponse(response, httpRequest.response);
    return;
  }

  Response? response;

  try {
    response = await handler(request);
  } on HijackException catch (error, stackTrace) {
    if (!request.canHijack) {
      return;
    }

    logError("Caught HijackException, but the request wasn't hijacked.\n$error",
        stackTrace);

    response = Response.internalServerError();
  } catch (error, stackTrace) {
    logError('Error thrown by handler.\n$error', stackTrace);
    response = Response.internalServerError();
  }

  if (response == null) {
    logError('Null response from handler', StackTrace.current);
    response = Response.internalServerError();
    await writeResponse(response, httpRequest.response);
    return;
  }

  if (request.canHijack) {
    await writeResponse(response, httpRequest.response);
    return;
  }

  var message = StringBuffer('Got a response for hijacked request ')
    ..write(request.method)
    ..write(' ')
    ..write(request.requestedUri)
    ..writeln(':')
    ..writeln(response.statusCode);

  void writeHeader(String key, String value) {
    message.writeln('$key: $value');
  }

  response.headers.forEach(writeHeader);
  throw Exception(message);
}

/// Creates a new [Request] from the provided [HttpRequest].
Request fromHttpRequest(HttpRequest request) {
  var headers = <String, List<String>>{};

  void setHeader(String key, List<String> values) {
    headers[key] = values;
  }

  request.headers.forEach(setHeader);

  // Remove the Transfer-Encoding header per the adapter requirements.
  headers.remove(HttpHeaders.transferEncodingHeader);

  void onHijack(void Function(StreamChannel<List<int>>) callback) {
    void onSocket(Socket socket) {
      callback(StreamChannel(socket, socket));
    }

    request.response.detachSocket(writeHeaders: false).then<void>(onSocket);
  }

  var context = <String, Object>{
    'shelf.io.connection_info': request.connectionInfo!
  };

  return Request(request.method, request.requestedUri,
      protocolVersion: request.protocolVersion,
      headers: headers,
      body: request,
      onHijack: onHijack,
      context: context);
}

/// Writes a given [Response] to the provided [HttpResponse].
Future<void> writeResponse(Response response, HttpResponse httpResponse) async {
  var bufferOutput = response.context['shelf.io.buffer_output'] as bool?;

  if (bufferOutput != null) {
    httpResponse.bufferOutput = bufferOutput;
  }

  httpResponse
    ..statusCode = response.statusCode
    // An adapter must not add or modify the `Transfer-Encoding` parameter,
    // but the Dart SDK sets it by default. Set this before we fill in
    // [response.headers] so that the user or Shelf can explicitly override
    // it if necessary.
    ..headers.chunkedTransferEncoding = false;

  response.headersAll.forEach(httpResponse.headers.set);

  var coding = response.headers['transfer-encoding'];

  if (coding != null && !equalsIgnoreAsciiCase(coding, 'identity')) {
    // If the response is already in a chunked encoding, de-chunk it because
    // otherwise `dart:io` will try to add another layer of chunking.
    // TODO(h11): Do this more cleanly when sdk#27886 is fixed.
    response = response.change(
      body: chunkedCoding.decoder.bind(response.read()),
    );

    httpResponse.headers.set(HttpHeaders.transferEncodingHeader, 'chunked');
  } else if (response.statusCode >= 200 &&
      response.statusCode != 204 &&
      response.statusCode != 304 &&
      response.contentLength == null &&
      response.mimeType != 'multipart/byteranges') {
    // If the response isn't chunked yet and there's no other way to tell its
    // length, enable `dart:io`'s chunked encoding.
    httpResponse.headers.set(HttpHeaders.transferEncodingHeader, 'chunked');
  }

  if (!response.headers.containsKey('X-Powered-By')) {
    httpResponse.headers.set('X-Powered-By', 'Astra.dart');
  }

  if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
    httpResponse.headers.date = DateTime.now().toUtc();
  }

  await response.read().pipe(httpResponse);
}
