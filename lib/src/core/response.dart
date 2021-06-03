import 'dart:async' show FutureOr;
import 'dart:convert' show json, utf8;

import 'http.dart';
import 'request.dart';
import 'types.dart';

class Response<T extends Object?> {
  Response({this.status = StatusCodes.ok, this.contentType, Map<String, String>? headers, T? content})
      : headers = MutableHeaders() {
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

    if (body.isNotEmpty && populateContentLength) {
      this.headers.add(Headers.contentLength, '${body.length}');
    }

    if (contentType != null && populateContentType) {
      this.headers.add(Headers.contentType, contentType!);
    }
  }

  int status;

  MutableHeaders headers;

  String? contentType;

  late List<int> body;

  FutureOr<void> call(Request request, Start start, Send send) {
    start(status: status, headers: headers.raw);
    return send(bytes: body, end: true);
  }

  List<int> render(T? content) {
    if (content == null) {
      return const <int>[];
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
  factory TextResponse.html(String? content,
      {int status = StatusCodes.ok, String contentType = ContentTypes.html, Map<String, String>? headers}) {
    return TextResponse(content, status: status, contentType: contentType, headers: headers);
  }

  TextResponse(String? content,
      {int status = StatusCodes.ok, String contentType = ContentTypes.text, Map<String, String>? headers})
      : super(status: status, contentType: contentType, headers: headers, content: content);

  @override
  List<int> render(String? content) {
    if (content == null) {
      return const <int>[];
    }

    return utf8.encode(content);
  }
}

class JSONResponse extends Response<Object> {
  JSONResponse(Object? content, {int status = StatusCodes.ok, Map<String, String>? headers})
      : super(status: status, contentType: ContentTypes.json, headers: headers, content: content);

  @override
  List<int> render(Object? content) {
    return utf8.encode(json.encode(content));
  }
}

class RedirectResponse extends Response {
  RedirectResponse(Uri url, {int status = StatusCodes.temporaryRedirect, Map<String, String>? headers})
      : super(status: status, headers: headers) {
    this.headers.set(Headers.location, '$url');
  }
}

class StreamResponse extends Response {
  factory StreamResponse.text(Stream<String> stream,
      {bool buffer = true,
      int status = StatusCodes.ok,
      String contentType = ContentTypes.text,
      Map<String, String>? headers}) {
    return StreamResponse(utf8.encoder.bind(stream),
        buffer: buffer, status: status, contentType: contentType, headers: headers);
  }

  factory StreamResponse.html(Stream<String> stream,
      {bool buffer = true,
      int status = StatusCodes.ok,
      String contentType = ContentTypes.html,
      Map<String, String>? headers}) {
    return StreamResponse(utf8.encoder.bind(stream),
        buffer: buffer, status: status, contentType: contentType, headers: headers);
  }

  factory StreamResponse.json(Stream<String> stream,
      {bool buffer = true,
      int status = StatusCodes.ok,
      String contentType = ContentTypes.json,
      Map<String, String>? headers}) {
    return StreamResponse(utf8.encoder.bind(stream),
        buffer: buffer, status: status, contentType: contentType, headers: headers);
  }

  StreamResponse(this.stream,
      {this.buffer = true,
      int status = StatusCodes.ok,
      String contentType = ContentTypes.stream,
      Map<String, String>? headers})
      : super(status: status, contentType: contentType, headers: headers);

  final Stream<List<int>> stream;

  final bool buffer;

  @override
  Future<void> call(Request request, Start start, Send send) async {
    start(status: status, headers: headers.raw, buffer: buffer);

    await for (var bytes in stream) {
      send(bytes: bytes);
    }

    return send(end: true);
  }
}
