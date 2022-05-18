import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:stream_channel/stream_channel.dart';

/// A HTTP/1.1 [Server] backed by a `dart:io` [HttpServer].
class H11IOServer extends Server {
  H11IOServer(this.server);

  /// The underlying [HttpServer].
  final HttpServer server;

  /// The underlying [HttpServer] incoming [HttpRequest] subscription.
  StreamSubscription<HttpRequest>? subscription;

  @override
  Uri get url {
    var address = server.address;

    if (address.isLoopback) {
      return Uri(scheme: 'http', host: 'localhost', port: server.port);
    }

    if (address.type == InternetAddressType.IPv6) {
      return Uri(scheme: 'http', host: '[${address.address}]', port: server.port);
    }

    return Uri(scheme: 'http', host: address.address, port: server.port);
  }

  @override
  void mount(Handler handler) {
    void ioHandler(HttpRequest request) {
      handleRequest(request, handler);
    }

    if (subscription != null) {
      subscription!.onData(ioHandler);
      return;
    }

    void listener() {
      subscription = server.listen(ioHandler);
    }

    catchTopLevelErrors(listener, (error, stackTrace) {
      logTopLevelError('asynchronous error\n$error', stackTrace);
    });
  }

  @override
  Future<void> close() {
    return server.close();
  }

  /// Calls [HttpServer.bind] and wraps the result in an [H11IOServer].
  static Future<H11IOServer> bind(Object address, int port, //
      {SecurityContext? securityContext,
      int backlog = 0,
      bool shared = false,
      bool requestClientCertificate = false,
      bool v6Only = false}) async {
    HttpServer server;

    if (securityContext == null) {
      server = await HttpServer.bind(address, port, //
          backlog: backlog,
          shared: shared,
          v6Only: v6Only);
    } else {
      server = await HttpServer.bindSecure(address, port, securityContext, //
          backlog: backlog,
          shared: shared,
          requestClientCertificate: requestClientCertificate,
          v6Only: v6Only);
    }

    return H11IOServer(server);
  }

  /// Uses [handler] to handle [httpRequest].
  ///
  /// Returns a [Future] which completes when the request has been handled.
  static Future<void> handleRequest(
      HttpRequest httpRequest, FutureOr<Response?> Function(Request) handler) async {
    Request request;

    try {
      request = fromHttpRequest(httpRequest);
    } on ArgumentError catch (error, stackTrace) {
      if (error.name == 'method' || error.name == 'requestedUri') {
        // TODO: use a reduced log level when using package:logging
        logTopLevelError('error parsing request.\n$error', stackTrace);

        const headers = <String, String>{HttpHeaders.contentTypeHeader: 'text/plain'};
        var response = Response.badRequest(body: 'Bad Request', headers: headers);
        await writeResponse(response, httpRequest.response);
      } else {
        logTopLevelError('error parsing request.\n$error', stackTrace);

        var response = Response.internalServerError();
        await writeResponse(response, httpRequest.response);
      }

      return;
    } catch (error, stackTrace) {
      logTopLevelError('error parsing request.\n$error', stackTrace);

      var response = Response.internalServerError();
      await writeResponse(response, httpRequest.response);
      return;
    }

    // TODO: abstract out hijack handling to make it easier to implement an adapter.
    Response? response;

    try {
      response = await handler(request);
    } on HijackException catch (error, stackTrace) {
      if (!request.canHijack) {
        return;
      }

      logError(request, 'caught HijackException, but the request wasn\'t hijacked.', stackTrace);
      response = Response.internalServerError();
    } catch (error, stackTrace) {
      logError(request, 'error thrown by handler.\n$error', stackTrace);
      response = Response.internalServerError();
    }

    if (response == null) {
      logError(request, 'null response from handler.', StackTrace.current);
      response = Response.internalServerError();
      return writeResponse(response, httpRequest.response);
    }

    if (request.canHijack) {
      return writeResponse(response, httpRequest.response);
    }

    var message = StringBuffer('got a response for hijacked request ')
      ..writeln('${request.method} ${request.requestedUri}:')
      ..writeln(response.statusCode);

    response.headers.forEach((key, value) {
      message.writeln('$key: $value');
    });

    throw Exception(message.toString().trim());
  }

  /// Creates a new [Request] from the provided [HttpRequest].
  static Request fromHttpRequest(HttpRequest request) {
    var headers = <String, List<String>>{};

    request.headers.forEach((key, value) {
      headers[key] = value;
    });

    // Remove the Transfer-Encoding header per the adapter requirements.
    headers.remove(HttpHeaders.transferEncodingHeader);

    void onHijack(void Function(StreamChannel<List<int>>) callback) {
      request.response
          .detachSocket(writeHeaders: false)
          .then((socket) => callback(StreamChannel(socket, socket)));
    }

    return Request(request.method, request.requestedUri, //
        protocolVersion: request.protocolVersion,
        headers: headers,
        body: request,
        onHijack: onHijack,
        context: <String, Object>{'shelf.io.connection_info': request.connectionInfo!});
  }

  /// Writes a given [Response] to the provided [HttpResponse].
  static Future<void> writeResponse(Response response, HttpResponse httpResponse) {
    if (response.context.containsKey('shelf.io.buffer_output')) {
      httpResponse.bufferOutput = response.context['shelf.io.buffer_output'] as bool;
    }

    httpResponse
      ..statusCode = response.statusCode
      ..headers.chunkedTransferEncoding = false;

    response.headersAll.forEach((header, value) {
      httpResponse.headers.set(header, value);
    });

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
      httpResponse.headers.set(HttpHeaders.serverHeader, 'Astra Server');
    }

    if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
      httpResponse.headers.date = DateTime.now().toUtc();
    }

    return response.read().pipe(httpResponse);
  }
}
