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
  void mount(Handler handler, [Logger? logger]) {
    if (mounted) {
      throw StateError('Can\'t mount two handlers for the same server.');
    }

    mounted = true;

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
    return requests.listen((request) {
      handleRequest(request, logger);
    });
  }

  Future<void> handleRequest(HttpRequest httpRequest, [Logger? logger]) async {
    Request request;

    try {
      request = fromHttpRequest(httpRequest);
    } on ArgumentError catch (error, stackTrace) {
      if (error.name == 'method' || error.name == 'requestedUri') {
        logger?.warning('Error parsing request.', error, stackTrace);

        const headers = <String, String>{HttpHeaders.contentTypeHeader: 'text/plain'};
        final response = Response.badRequest(body: 'Bad Request', headers: headers);
        await writeResponse(response, httpRequest.response);
      } else {
        logger?.severe('Error parsing request.', error, stackTrace);

        final response = Response.internalServerError();
        await writeResponse(response, httpRequest.response);
      }

      return;
    } catch (error, stackTrace) {
      logger?.severe('Error parsing request.', error, stackTrace);

      final response = Response.internalServerError();
      await writeResponse(response, httpRequest.response);
      return;
    }

    // TODO: abstract out hijack handling to make it easier to implement an adapter.
    Response? response;

    try {
      response = await this(request);
    } on HijackException catch (error, stackTrace) {
      if (!request.canHijack) {
        return;
      }

      logger?.severe('Caught HijackException, but the request wasn\'t hijacked.', error, stackTrace);
      response = Response.internalServerError();
    } catch (error, stackTrace) {
      logger?.severe('Error thrown by handler.', error, stackTrace);
      response = Response.internalServerError();
    }

    if (response == null) {
      logger?.severe('Null response from handler.', '', StackTrace.current);
      response = Response.internalServerError();
      return writeResponse(response, httpRequest.response);
    }

    if (request.canHijack) {
      return writeResponse(response, httpRequest.response);
    }

    final message = StringBuffer('got a response for hijacked request ')
      ..write(request.method)
      ..write(' ')
      ..writeln(request.requestedUri)
      ..writeln(response.statusCode);

    response.headers.forEach((key, value) {
      message.writeln('$key: $value');
    });

    throw Exception(message.toString().trim());
  }

  /// Creates a new [Request] from the provided [HttpRequest].
  static Request fromHttpRequest(HttpRequest request) {
    final headers = <String, List<String>>{};

    request.headers.forEach((key, value) {
      headers[key] = value;
    });

    // Remove the Transfer-Encoding header per the adapter requirements.
    headers.remove(HttpHeaders.transferEncodingHeader);

    void onHijack(void Function(StreamChannel<List<int>>) callback) {
      request.response
          .detachSocket(writeHeaders: false)
          .then<void>((socket) => callback(StreamChannel(socket, socket)));
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

    final coding = response.headers['transfer-encoding'];

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
