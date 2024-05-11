import 'dart:async' show FutureOr, Zone, runZonedGuarded;
import 'dart:io' show HttpHeaders, HttpRequest, HttpResponse, Socket;

import 'package:astra/src/core/error.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
import 'package:collection/collection.dart' show equalsIgnoreAsciiCase;
import 'package:http_parser/http_parser.dart' show chunkedCoding;
import 'package:logging/logging.dart' show Logger;
import 'package:stream_channel/stream_channel.dart' show StreamChannel;

Future<void> _handleRequest(
  HttpRequest httpRequest,
  FutureOr<Response?> Function(Request) handler,
  Logger? logger,
) async {
  Request request;

  try {
    request = _fromHttpRequest(httpRequest);
  } on ArgumentError catch (error, stackTrace) {
    if (error.name == 'method' || error.name == 'requestedUri') {
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

  var context = <String, Object>{
    'shelf.io.connection_info': request.connectionInfo!,
    if (request.certificate != null)
      'astra.server.certificate': request.certificate!,
  };

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
  const kBufferOutput = 'shelf.io.buffer_output';

  if (response.context.containsKey(kBufferOutput)) {
    httpResponse.bufferOutput = response.context[kBufferOutput] as bool;
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

  if (!response.headers.containsKey('x-powered-by')) {
    httpResponse.headers.set('x-powered-by', 'astra.dart');
  }

  if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
    httpResponse.headers.date = DateTime.now().toUtc();
  }

  await response.read().pipe(httpResponse);
}

/// Serve a [Stream] of [HttpRequest]s.
///
/// Errors thrown by [handler] while serving a request will be printed to the
/// console and cause a `500` response with no body. Errors thrown
/// asynchronously by [handler] will be printed to the console or, if there's an
/// active error zone, passed to that zone.
///
/// Every response will get a 'date' header and an 'x-powered-by' header. If the
/// either header is present in the [Response], it will not be overwritten.
void serveRequests(
  Stream<HttpRequest> requests,
  Handler handler,
  Logger? logger,
) {
  void onRequest(HttpRequest httpRequest) {
    _handleRequest(httpRequest, handler, logger);
  }

  void body() {
    requests.listen(onRequest);
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
