library astra.serve.h11;

import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:stream_channel/stream_channel.dart';

/// A HTTP/1.1 [Server] backed by a `dart:io` [HttpServer].
class H11Server implements Server {
  H11Server(this.server) : mounted = false;

  /// The underlying [HttpServer].
  final HttpServer server;

  @protected
  bool mounted;

  @override
  InternetAddress get address {
    return server.address;
  }

  @override
  int get port {
    return server.port;
  }

  @override
  Future<void> mount(Application application, [Logger? logger]) async {
    if (mounted) {
      throw StateError('Can\'t mount two handlers for the same server.');
    }

    mounted = true;

    await application.prepare();

    var handler = application.entryPoint;

    void body() {
      handler.handleRequests(server, logger);
    }

    void onError(Object error, StackTrace stackTrace) {
      logger?.warning('Asynchronous error.', error, stackTrace);
    }

    catchTopLevelErrors(body, onError);
  }

  @override
  Future<void> close({bool force = false}) {
    return server.close(force: force);
  }

  /// Calls [HttpServer.bind] and wraps the result in an [H11Server].
  static Future<H11Server> bind(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false}) async {
    HttpServer server;

    if (securityContext == null) {
      server = await HttpServer.bind(address, port, //
          backlog: backlog,
          v6Only: v6Only,
          shared: shared);
    } else {
      server = await HttpServer.bindSecure(address, port, securityContext, //
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared);
    }

    return H11Server(server);
  }
}

extension on FutureOr<Response?> Function(Request) {
  StreamSubscription<HttpRequest> handleRequests(Stream<HttpRequest> requests, [Logger? logger]) {
    void onRequest(HttpRequest request) {
      handleRequest(request, logger);
    }

    return requests.listen(onRequest);
  }

  // TODO: error response with message
  Future<void> handleRequest(HttpRequest httpRequest, [Logger? logger]) {
    Request request;

    try {
      request = fromHttpRequest(httpRequest);
    } on ArgumentError catch (error, stackTrace) {
      if (error.name == 'method' || error.name == 'requestedUri') {
        logger?.warning('Error parsing request.', error, stackTrace);

        var headers = <String, String>{HttpHeaders.contentTypeHeader: 'text/plain'};
        var response = Response.badRequest(body: 'Bad Request', headers: headers);
        return writeResponse(response, httpRequest.response);
      }

      logger?.severe('Error parsing request.', error, stackTrace);

      var response = Response.internalServerError();
      return writeResponse(response, httpRequest.response);
    } catch (error, stackTrace) {
      logger?.severe('Error parsing request.', error, stackTrace);

      var response = Response.internalServerError();
      return writeResponse(response, httpRequest.response);
    }

    var done = Completer<void>.sync();
    var response = Completer<Response?>();

    // TODO: abstract out hijack handling to make it easier to implement an adapter.
    Future<void> onResponse(Response? response) {
      if (response == null) {
        logger?.severe('Null response from handler.', '', StackTrace.current);
        response = Response.internalServerError();
        return writeResponse(response, httpRequest.response);
      }

      if (request.canHijack) {
        return writeResponse(response, httpRequest.response);
      }

      var message = StringBuffer('got a response for hijacked request ')
        ..write(request.method)
        ..write(' ')
        ..writeln(request.requestedUri)
        ..writeln(response.statusCode);

      void writeHeader(String key, String value) {
        message.writeln('$key: $value');
      }

      response.headers.forEach(writeHeader);

      throw Exception(message);
    }

    response.future.then<void>(onResponse).catchError(done.completeError);

    FutureOr<Response?> computation() {
      return this(request);
    }

    void onHijack(Object error, StackTrace stackTrace) {
      if (!request.canHijack) {
        done.complete();
        return;
      }

      logger?.severe('Caught HijackException, but the request wasn\'t hijacked.', error, stackTrace);
      response.complete(Response.internalServerError());
    }

    bool hijactTest(Object error) {
      return error is HijackException;
    }

    void onError(Object error, StackTrace stackTrace) {
      logger?.severe('Error thrown by handler.', error, stackTrace);
      response.complete(Response.internalServerError());
    }

    Future<Response?>.sync(computation)
        .then<void>(response.complete)
        .catchError(onHijack, test: hijactTest)
        .catchError(onError);

    return done.future;
  }

  /// Creates a new [Request] from the provided [HttpRequest].
  static Request fromHttpRequest(HttpRequest request) {
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

    return Request(request.method, request.requestedUri,
        protocolVersion: request.protocolVersion,
        headers: headers,
        body: request,
        onHijack: onHijack,
        context: <String, Object>{'shelf.io.connection_info': request.connectionInfo!});
  }

  /// Writes a given [Response] to the provided [1HttpResponse].
  static Future<void> writeResponse(Response response, HttpResponse httpResponse) {
    if (response.context.containsKey('shelf.io.buffer_output')) {
      httpResponse.bufferOutput = response.context['shelf.io.buffer_output'] as bool;
    }

    httpResponse
      ..statusCode = response.statusCode
      ..headers.chunkedTransferEncoding = false;

    response.headersAll.forEach(httpResponse.headers.set);

    var coding = response.headers['transfer-encoding'];

    if (coding != null && !equalsIgnoreAsciiCase(coding, 'identity')) {
      // If the response is already in a chunked encoding, de-chunk it because
      // otherwise `dart:io` will try to add another layer of chunking.
      // TODO: Do this more cleanly when sdk#27886 is fixed.
      response = response.change(body: chunkedCoding.decoder.bind(response.read()));
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

    if (!response.headers.containsKey(HttpHeaders.serverHeader)) {
      httpResponse.headers.set(HttpHeaders.serverHeader, 'Astra $packageVersion');
    }

    if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
      httpResponse.headers.date = DateTime.now().toUtc();
    }

    return response.read().pipe(httpResponse);
  }
}
