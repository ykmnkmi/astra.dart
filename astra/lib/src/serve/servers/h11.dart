import 'dart:async' show FutureOr, StreamSubscription, Zone, runZonedGuarded;
import 'dart:io'
    show HttpHeaders, HttpRequest, HttpResponse, HttpServer, Socket;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/error.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
import 'package:astra/src/serve/server.dart';
import 'package:collection/collection.dart' show equalsIgnoreAsciiCase;
import 'package:http_parser/http_parser.dart' show chunkedCoding;
import 'package:stream_channel/stream_channel.dart' show StreamChannel;

const String _bufferOutputKey = 'shelf.io.buffer_output';

const String _connectionInfoKey = 'shelf.io.connection_info';

/// HTTP/1.1 [Server] implementation.
base class H11Server extends Server {
  H11Server(
    super.address,
    super.port, {
    super.securityContext,
    super.backlog,
    super.v6Only,
    super.requestClientCertificate,
    super.shared,
    super.identifier,
    super.logger,
  });

  HttpServer? _server;

  Application? _application;

  StreamSubscription<HttpRequest>? _subscription;

  @override
  Application? get application => _application;

  @override
  Object get address {
    if (_server case var server?) {
      return server.address;
    }

    return super.address;
  }

  @override
  int get port {
    if (_server case var server?) {
      return server.port;
    }

    return super.port;
  }

  @override
  bool get isRunning => _subscription != null;

  Future<void> _handleRequest(
    HttpRequest httpRequest,
    FutureOr<Response?> Function(Request) handler,
  ) async {
    Request request;

    try {
      request = _fromHttpRequest(httpRequest);
    } on ArgumentError catch (error, stackTrace) {
      if (error.name case 'method' || 'requestedUri') {
        logger?.severe('Error parsing request.', error, stackTrace);

        var response = Response.badRequest(body: 'Bad Request');
        await _writeResponse(response, httpRequest.response);
      } else {
        logger?.severe('Error parsing request.', error, stackTrace);

        var response = Response.internalServerError();
        await _writeResponse(response, httpRequest.response);
      }

      return;
    } catch (error, stackTrace) {
      logger?.severe('Error parsing request.', error, stackTrace);

      var response = Response.internalServerError();
      await _writeResponse(response, httpRequest.response);
      return;
    }

    Response? response;

    try {
      response = await handler(request);
    } on HijackException catch (error, stackTrace) {
      if (!request.canHijack) {
        return;
      }

      logger?.severe("Caught HijackException, but the request wasn't hijacked.",
          error, stackTrace);

      response = Response.internalServerError();
    } catch (error, stackTrace) {
      logger?.severe('Error thrown by handler.', error, stackTrace);
      response = Response.internalServerError();
    }

    if (response == null) {
      logger?.severe('Null response from handler.');
      response = Response.internalServerError();
      await _writeResponse(response, httpRequest.response);
      return;
    }

    if (request.canHijack) {
      await _writeResponse(response, httpRequest.response);
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

  Request _fromHttpRequest(HttpRequest request) {
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

    var context = <String, Object>{_connectionInfoKey: request.connectionInfo!};

    return Request(request.method, request.requestedUri,
        protocolVersion: request.protocolVersion,
        headers: headers,
        body: request,
        onHijack: onHijack,
        context: context);
  }

  Future<void> _writeResponse(
    Response response,
    HttpResponse httpResponse,
  ) async {
    if (response.context.containsKey(_bufferOutputKey)) {
      httpResponse.bufferOutput = response.context[_bufferOutputKey] as bool;
    }

    httpResponse
      ..statusCode = response.statusCode
      // An adapter must not add or modify the `Transfer-Encoding` parameter,
      // but the Dart SDK sets it by default. Set this before we fill in
      // [response.headers] so that the user or shelf can explicitly override
      // it if necessary.
      ..headers.chunkedTransferEncoding = false;

    response.headersAll.forEach(httpResponse.headers.set);

    var coding = response.headers['transfer-encoding'];

    if (coding != null && !equalsIgnoreAsciiCase(coding, 'identity')) {
      // If the response is already in a chunked encoding, de-chunk it because
      // otherwise `dart:io` will try to add another layer of chunking.
      // TODO(serve): Do this more cleanly when sdk#27886 is fixed.
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
      httpResponse.headers.set('X-Powered-By', 'astra.dart');
    }

    if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
      httpResponse.headers.date = DateTime.now().toUtc();
    }

    await response.read().pipe(httpResponse);
  }

  void _serveRequests(Handler handler) {
    void onRequest(HttpRequest httpRequest) {
      _handleRequest(httpRequest, handler);
    }

    void body() {
      _subscription = _server!.listen(onRequest);
    }

    if (Zone.current.inSameErrorZone(Zone.root)) {
      void onError(Object error, StackTrace stackTrace) {
        logger?.severe('Asynchronous error.', error, stackTrace);
      }

      runZonedGuarded(body, onError);
    } else {
      body();
    }
  }

  @override
  Future<void> handle(Handler handler) async {
    logger?.fine('Handling handler.'); // what?

    if (_subscription != null) {
      throw StateError("Can't mount two handlers for the same server.");
    }

    logger?.fine('Binding HTTP server.');

    if (securityContext case var context?) {
      _server = await HttpServer.bindSecure(address, port, context,
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared);
    } else {
      _server = await HttpServer.bind(address, port,
          backlog: backlog, v6Only: v6Only, shared: shared);
    }

    logger?.fine('Bound HTTP server.');
    logger?.fine('Listening for requests.');
    _serveRequests(handler);
    logger?.info('Server astra/$identifier started.');
  }

  @override
  Future<void> mount(Application application) async {
    logger?.fine('Mounting application.');

    if (_application != null) {
      throw StateError("Can't mount two applications for the same server.");
    }

    _application = application;
    application.server = this;

    logger?.fine('Preparing application.');
    await application.prepare();
    await handle(application.entryPoint);
  }

  @override
  Future<void> close({bool force = false}) async {
    logger?.fine('Closing server.');

    if (_server case var server?) {
      await server.close(force: force);
      _server = null;
      _subscription = null;
    }

    logger?.fine('Closing application.');

    if (_application case var application?) {
      await application.close();
      _application = null;
    }

    logger?.info('Server astra/$identifier closed.');
  }
}
