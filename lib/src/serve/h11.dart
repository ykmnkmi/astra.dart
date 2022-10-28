import 'dart:async' show FutureOr, StreamSubscription;
import 'dart:io' show HttpHeaders, InternetAddress, InternetAddressType, SecurityContext, Socket;

import 'package:astra/core.dart';
import 'package:astra/http.dart';
import 'package:astra/src/serve/utils.dart';
import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:stream_channel/stream_channel.dart';

/// A HTTP/1.1 [Server] backed by a `dart:io` [Socket] server.
class H11Server implements Server {
  H11Server(this.server);

  /// The underlying [HttpServer].
  final NativeServer server;

  /// Mounted [Application]
  @override
  Application? application;

  @override
  InternetAddress get address {
    return server.address;
  }

  @override
  int get port {
    return server.port;
  }

  @override
  Uri get url {
    if (address.isLoopback) {
      return Uri(scheme: 'http', host: 'localhost', port: port);
    }

    if (address.type == InternetAddressType.IPv6) {
      return Uri(scheme: 'http', host: '[${address.address}]', port: port);
    }

    return Uri(scheme: 'http', host: address.address, port: port);
  }

  @override
  Future<void> mount(Application application) async {
    if (this.application != null) {
      throw StateError('Can\'t mount two handlers for the same server.');
    }

    this.application = application;
    await application.prepare();

    var handler = application.entryPoint;

    void body() {
      handler.handleRequests(server);
    }

    void onError(Object error, StackTrace stackTrace) {
      logError('Asynchronous error.\n$error', stackTrace);
    }

    catchTopLevelErrors(body, onError);
  }

  @override
  Future<void> close({bool force = false}) async {
    await server.close(force: force);

    var application = this.application;

    if (application != null) {
      await application.close();
    }
  }

  /// Bounds the server socket to the given [address] and [port] and wraps in an [H11Server].
  static Future<H11Server> bind(Object address, int port,
      {SecurityContext? securityContext,
      int backlog = 0,
      bool v6Only = false,
      bool requestClientCertificate = false,
      bool shared = false}) async {
    NativeServer server;

    if (securityContext == null) {
      server = await NativeServer.bind(address, port, //
          backlog: backlog,
          v6Only: v6Only,
          shared: shared);
    } else {
      server = await NativeServer.bindSecure(address, port, securityContext, //
          backlog: backlog,
          v6Only: v6Only,
          requestClientCertificate: requestClientCertificate,
          shared: shared);
    }

    return H11Server(server);
  }
}

// From `shelf` package with overriden logging.
// TODO: sdk#27886.
// An adapter must not add or modify the `Transfer-Encoding` parameter,
// but the Dart SDK sets it by default. Set this before we fill in
// [response.headers] so that the user or adapter can explicitly override
// it if necessary.
extension on FutureOr<Response?> Function(Request) {
  StreamSubscription<NativeRequest> handleRequests(Stream<NativeRequest> requests) {
    return requests.listen(handleRequest);
  }

  // TODO: error response with message
  Future<void> handleRequest(NativeRequest httpRequest) async {
    Request request;

    try {
      request = fromHttpRequest(httpRequest);
    } on ArgumentError catch (error, stackTrace) {
      if (error.name == 'method' || error.name == 'requestedUri') {
        logError('Error parsing request.\n$error', stackTrace);

        var headers = <String, String>{HttpHeaders.contentTypeHeader: 'text/plain'};
        var response = Response.badRequest(body: 'Bad Request', headers: headers);
        await writeResponse(response, httpRequest.response);
        return;
      }

      logError('Error parsing request.\n$error', stackTrace);

      var response = Response.internalServerError();
      await writeResponse(response, httpRequest.response);
      return;
    } catch (error, stackTrace) {
      logError('Error parsing request.\n$error', stackTrace);

      var response = Response.internalServerError();
      await writeResponse(response, httpRequest.response);
      return;
    }

    Response? response;

    try {
      response = await this(request);
    } on HijackException catch (error, stackTrace) {
      if (!request.canHijack) {
        return;
      }

      logError("Caught HijackException, but the request wasn't hijacked.\n$error", stackTrace);
      response = Response.internalServerError();
    } catch (error, stackTrace) {
      logError('Error thrown by handler.\n$error', stackTrace);
      response = Response.internalServerError();
    }

    if (response == null) {
      logError('Null response from handler.', StackTrace.current);
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

  /// Creates a new [Request] from the provided [NativeRequest].
  static Request fromHttpRequest(NativeRequest request) {
    var headers = <String, List<String>>{};

    void setHeader(String key, List<String> values) {
      headers[key] = values;
    }

    request.headers.forEach(setHeader);
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

  /// Writes a given [Response] to the provided [NativeResponse].
  static Future<void> writeResponse(Response response, NativeResponse nativeResponse) {
    if (response.context.containsKey('shelf.io.buffer_output')) {
      nativeResponse.bufferOutput = response.context['shelf.io.buffer_output'] as bool;
    }

    nativeResponse
      ..statusCode = response.statusCode
      ..headers.chunkedTransferEncoding = false;

    response.headersAll.forEach(nativeResponse.headers.setAll);

    var coding = response.headers['transfer-encoding'];

    if (coding != null && !equalsIgnoreAsciiCase(coding, 'identity')) {
      // If the response is already in a chunked encoding, de-chunk it because
      // otherwise `dart:io` will try to add another layer of chunking.
      response = response.change(body: chunkedCoding.decoder.bind(response.read()));
      nativeResponse.headers.set(HttpHeaders.transferEncodingHeader, 'chunked');
    } else if (response.statusCode >= 200 &&
        response.statusCode != 204 &&
        response.statusCode != 304 &&
        response.contentLength == null &&
        response.mimeType != 'multipart/byteranges') {
      // If the response isn't chunked yet and there's no other way to tell its
      // length, enable `dart:io`'s chunked encoding.
      nativeResponse.headers.set(HttpHeaders.transferEncodingHeader, 'chunked');
    }

    if (!response.headers.containsKey('x-powered-by')) {
      nativeResponse.headers.set('x-powered-by', 'Astra $packageVersion');
    }

    if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
      nativeResponse.headers.date = DateTime.now().toUtc();
    }

    return response.read().pipe(nativeResponse);
  }
}
