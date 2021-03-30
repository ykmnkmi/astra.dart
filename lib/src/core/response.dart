import 'dart:convert' show json, utf8;
import 'dart:io' show HttpStatus;

import 'package:http2/http2.dart' show Header;

import 'http.dart';
import 'type.dart';

class Response<T extends Object?> {
  Response({this.status = HttpStatus.ok, this.contentType, Map<String, String>? headers, T? content}) : raw = <Header>[] {
    body = render(content);

    var populateContentLength = true;
    var populateContentType = true;

    if (headers != null) {
      final keys = <String>{};

      for (final entry in headers.entries) {
        keys.add(entry.key);
        raw.add(Header.ascii(entry.key.toLowerCase(), entry.value));
        populateContentLength = !keys.contains('Content-Length');
        populateContentType = !keys.contains('Content-Type');
      }
    }

    if (body != null && body!.isNotEmpty && populateContentLength) {
      raw.add(Header.ascii('Content-Length', body!.length.toString()));
    }

    if (contentType != null && populateContentType) {
      raw.add(Header.ascii('Content-Type', contentType!));
    }
  }

  int status;

  List<Header> raw;

  String? contentType;

  List<int>? body;

  MutableHeaders get headers {
    return MutableHeaders(raw: raw);
  }

  void call(Map<String, Object?> scope, Start start, Respond respond) {
    start(status, raw);

    if (body != null) {
      respond(body!);
    }
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
  TextResponse(String? content, {int status = HttpStatus.ok, String contentType = ContentTypes.text, Map<String, String>? headers})
      : super(status: status, contentType: contentType, headers: headers, content: content);

  @override
  List<int> render(String? content) {
    if (content == null) {
      return const <int>[];
    }

    return utf8.encode(content);
  }
}

class HTMLResponse extends TextResponse {
  HTMLResponse(String? content, {int status = HttpStatus.ok, Map<String, String>? headers})
      : super(content, status: status, contentType: ContentTypes.html, headers: headers);
}

class JSONResponse extends Response<Object> {
  JSONResponse(Object? content, {int status = HttpStatus.ok, Map<String, String>? headers})
      : super(status: status, contentType: ContentTypes.json, headers: headers, content: content);

  @override
  List<int> render(Object? content) {
    return utf8.encode(json.encode(content));
  }
}
