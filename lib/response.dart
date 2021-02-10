import 'dart:convert';
import 'dart:io';

import 'http.dart';
import 'headers.dart';

typedef Start = Future<void> Function(int statusCode, List<Header> headers);

typedef Respond = Future<void> Function(List<int> body);

abstract class Response<T extends Object> {
  Response({this.statusCode = HttpStatus.ok, this.contentType = ContentTypes.text, Map<String, String>? headers, T? content}) : rawHeaders = <Header>[] {
    body = render(content);

    var populateContentLength = true;
    var populateContentType = true;

    if (headers != null) {
      final keys = <String>{};

      for (final entry in headers.entries) {
        keys.add(entry.key);
        rawHeaders.add(Header(ascii.encode(entry.key.toLowerCase()), ascii.encode(entry.value)));
        populateContentLength = !keys.contains('content-length');
        populateContentType = !keys.contains('content-type');
      }
    }

    if (body.isNotEmpty && populateContentLength) {
      rawHeaders.add(Header(ascii.encode('content-length'), ascii.encode(body.length.toString())));
    }

    if (populateContentType) {
      rawHeaders.add(Header(ascii.encode('content-type'), ascii.encode(contentType)));
    }
  }

  int statusCode;

  String contentType;

  List<Header> rawHeaders;

  late List<int> body;

  MutableHeaders get headers => MutableHeaders(raw: rawHeaders);

  Future<void> call(Start start, Respond respond) async {
    await start(statusCode, rawHeaders);
    await respond(body);
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

    throw Exception('wrong type: ${content.runtimeType}');
  }
}

class PlainTextResponse extends Response<String> {
  PlainTextResponse({int statusCode = HttpStatus.ok, Map<String, String>? headers, String? content})
      : super(statusCode: statusCode, headers: headers, content: content);
}

class HTMLResponse extends Response<String> {
  HTMLResponse({int statusCode = HttpStatus.ok, Map<String, String>? headers, String? content})
      : super(statusCode: statusCode, contentType: ContentTypes.html, headers: headers, content: content);
}

class JSONResponse extends Response<Object> {
  JSONResponse({int statusCode = HttpStatus.ok, Map<String, String>? headers, Object? content})
      : super(statusCode: statusCode, contentType: ContentTypes.json, headers: headers, content: content);
}
