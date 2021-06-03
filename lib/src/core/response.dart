import 'dart:async' show FutureOr;
import 'dart:convert' show json, utf8;
import 'dart:io' show HttpStatus;

import 'http.dart';
import 'request.dart';
import 'types.dart';

class Response<T extends Object?> {
  Response({
    this.status = HttpStatus.ok,
    this.contentType,
    Map<String, String>? headers,
    T? content,
  }) : headers = MutableHeaders() {
    body = render(content);

    var populateContentLength = true;
    var populateContentType = true;

    if (headers != null) {
      final keys = <String>{};

      for (final entry in headers.entries) {
        keys.add(entry.key);
        this.headers.add(entry.key.toLowerCase(), entry.value);
        populateContentLength = !keys.contains(Headers.contentLength);
        populateContentType = !keys.contains(Headers.contentType);
      }
    }

    if (body != null && body!.isNotEmpty && populateContentLength) {
      this.headers.add(Headers.contentLength, body!.length.toString());
    }

    if (contentType != null && populateContentType) {
      this.headers.add(Headers.contentType, contentType!);
    }
  }

  int status;

  MutableHeaders headers;

  String? contentType;

  List<int>? body;

  FutureOr<void> call(Request request, Start start, Send send) {
    start(status: status, headers: headers.raw);
    return send(bytes: body ?? const <int>[], end: true);
  }

  List<int>? render(T? content) {
    if (content == null) {
      return null;
    }

    if (content is List<int>) {
      return content;
    }

    if (content is String) {
      return utf8.encode(content);
    }

    if (content is Iterable<int>) {
      return content.toList();
    }

    throw TypeError();
  }
}

class TextResponse extends Response<String> {
  TextResponse(
    String? content, {
    int status = HttpStatus.ok,
    String contentType = ContentTypes.text,
    Map<String, String>? headers,
  }) : super(
          status: status,
          contentType: contentType,
          headers: headers,
          content: content,
        );

  @override
  List<int> render(String? content) {
    if (content == null) {
      return const <int>[];
    }

    return utf8.encode(content);
  }
}

class HTMLResponse extends TextResponse {
  HTMLResponse(
    String? content, {
    int status = HttpStatus.ok,
    Map<String, String>? headers,
  }) : super(
          content,
          status: status,
          contentType: ContentTypes.html,
          headers: headers,
        );
}

class JSONResponse extends Response<Object> {
  JSONResponse(
    Object? content, {
    int status = HttpStatus.ok,
    Map<String, String>? headers,
  }) : super(
          status: status,
          contentType: ContentTypes.json,
          headers: headers,
          content: content,
        );

  @override
  List<int> render(Object? content) {
    return utf8.encode(json.encode(content));
  }
}

class RedirectResponse extends Response {
  RedirectResponse(
    Uri url, {
    int status = HttpStatus.temporaryRedirect,
    Map<String, String>? headers,
  }) : super(
          status: status,
          headers: headers,
        ) {
    this.headers.set(Headers.location, '$url');
  }
}

class StreamResponse extends Response {
  StreamResponse(
    this.stream, {
    this.buffer = true,
    int status = HttpStatus.ok,
    String? contentType,
    Map<String, String>? headers,
  }) : super(
          status: status,
          contentType: contentType,
          headers: headers,
        );

  final Stream<List<int>> stream;

  final bool buffer;

  @override
  Future<void> call(Request request, Start start, Send send) {
    start(status: status, headers: headers.raw, buffer: buffer);
    return stream.forEach((bytes) => send(bytes: bytes)).then((_) => send(end: true));
  }
}
