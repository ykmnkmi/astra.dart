import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';

Future<HttpServer> serve(Handler handler, Object address, int port,
    {SecurityContext? securityContext, int backlog = 0, bool shared = false}) async {
  var server = await (securityContext == null
      ? HttpServer.bind(address, port, backlog: backlog, shared: shared)
      : HttpServer.bindSecure(address, port, securityContext, backlog: backlog, shared: shared));
  serveRequests(server, handler);
  return server;
}

void serveRequests(Stream<HttpRequest> requests, Handler handler) {
  catchTopLevelErrors(() {
    requests.listen((request) => handleRequest(request, handler));
  }, (error, stackTrace) {
    logTopLevelError('Asynchronous error\n$error', stackTrace);
  });
}

Future<void> handleRequest(HttpRequest request, Handler handler) async {
  Request shelfRequest;

  try {
    shelfRequest = fromHttpRequest(request);
  } on ArgumentError catch (error, stackTrace) {
    if (error.name == 'method' || error.name == 'requestedUri') {
      logTopLevelError('Error parsing request.\n$error', stackTrace);

      final response = Response(400,
          body: 'Bad Request',
          headers: <String, Object>{HttpHeaders.contentTypeHeader: 'text/plain'});
      await writeResponse(response, request.response);
    } else {
      logTopLevelError('Error parsing request.\n$error', stackTrace);

      final response = Response.internalServerError();
      await writeResponse(response, request.response);
    }

    return;
  } catch (error, stackTrace) {
    logTopLevelError('Error parsing request.\n$error', stackTrace);
    final response = Response.internalServerError();
    await writeResponse(response, request.response);
    return;
  }

  Response? response;

  try {
    response = await handler(shelfRequest);
  } on HijackException catch (error, stackTrace) {
    // A HijackException should bypass the response-writing logic entirely.
    if (!shelfRequest.canHijack) {
      return;
    }

    // If the request wasn't hijacked, we shouldn't be seeing this exception.
    response = logError(
        shelfRequest, 'Caught HijackException, but the request wasn\'t hijacked.', stackTrace);
  } catch (error, stackTrace) {
    response = logError(shelfRequest, 'Error thrown by handler.\n$error', stackTrace);
  }

  if ((response as Object?) == null) {
    response = logError(shelfRequest, 'null response from handler.', StackTrace.current);
    await writeResponse(response, request.response);
    return;
  }

  if (shelfRequest.canHijack) {
    await writeResponse(response, request.response);
    return;
  }

  var message = StringBuffer('Got a response for hijacked request ')
    ..writeln(shelfRequest.method)
    ..writeln(' ')
    ..writeln(shelfRequest.requestedUri)
    ..writeln(':')
    ..writeln(response.statusCode);

  response.headers.forEach((key, value) {
    message
      ..writeln(key)
      ..writeln(': ')
      ..writeln(value);
  });

  throw Exception(message.toString().trim());
}

Request fromHttpRequest(HttpRequest request) {
  var headers = <String, List<String>>{};

  request.headers.forEach((k, v) {
    headers[k] = v;
  });

  // Remove the Transfer-Encoding header per the adapter requirements.
  headers.remove(HttpHeaders.transferEncodingHeader);

  Future<void> onHijack(void Function(StreamChannel<List<int>>) callback) async {
    var socket = await request.response.detachSocket(writeHeaders: false);
    callback(StreamChannel(socket, socket));
  }

  return Request(request.method, request.requestedUri,
      protocolVersion: request.protocolVersion,
      headers: headers,
      body: request,
      onHijack: onHijack,
      context: <String, Object>{'shelf.io.connection_info': request.connectionInfo!});
}

Future<void> writeResponse(Response response, HttpResponse httpResponse) {
  if (response.context.containsKey('shelf.io.buffer_output')) {
    httpResponse.bufferOutput = response.context['shelf.io.buffer_output'] as bool;
  }

  httpResponse.statusCode = response.statusCode;

  // An adapter must not add or modify the `Transfer-Encoding` parameter, but
  // the Dart SDK sets it by default. Set this before we fill in
  // [response.headers] so that the user or Shelf can explicitly override it if
  // necessary.
  httpResponse.headers.chunkedTransferEncoding = false;

  response.headersAll.forEach((header, value) {
    httpResponse.headers.set(header, value);
  });

  var coding = response.headers['transfer-encoding'];

  if (coding != null && !equalsIgnoreAsciiCase(coding, 'identity')) {
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
    httpResponse.headers.set(HttpHeaders.serverHeader, 'Astra with Shelf');
  }

  if (!response.headers.containsKey(HttpHeaders.dateHeader)) {
    httpResponse.headers.date = DateTime.now().toUtc();
  }

  return response.read().pipe(httpResponse);
}

Response logError(Request request, String message, StackTrace stackTrace) {
  var buffer = StringBuffer(request.method)
    ..write(' ')
    ..write(request.requestedUri.path);

  if (request.requestedUri.query.isNotEmpty) {
    buffer
      ..write('?')
      ..write(request.requestedUri.query);
  }

  buffer
    ..writeln()
    ..write(message);

  logTopLevelError(buffer.toString(), stackTrace);
  return Response.internalServerError();
}

void logTopLevelError(String message, StackTrace stackTrace) {
  final chain = Chain.forTrace(stackTrace)
      .foldFrames((frame) => frame.isCore || frame.package == 'shelf')
      .terse;

  stderr.writeln('ERROR - ${DateTime.now()}');
  stderr.writeln(message);
  stderr.writeln(chain);
}

void catchTopLevelErrors(
    void Function() callback, void Function(Object error, StackTrace stackTrace) onError) {
  if (Zone.current.inSameErrorZone(Zone.root)) {
    return runZonedGuarded(callback, onError);
  }

  return callback();
}
