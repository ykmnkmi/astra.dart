import 'dart:convert';
import 'dart:io';

import 'body.dart';
import 'content_types.dart';
import 'headers.dart';
import 'types.dart';

abstract class Response {
  Response({this.statusCode = HttpStatus.ok, this.contentType = ContentTypes.text, Map<String, String> responseHeaders, Object content})
      : rawHeaders = <Header>[],
        body = bytes(content) {
    var populateContentLength = true;
    var populateContentType = true;

    if (responseHeaders != null) {
      final keys = <String>{};

      for (final entry in responseHeaders.entries) {
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

  List<int> body;

  MutableHeaders get headers => MutableHeaders(raw: rawHeaders);

  Future<void> call(Start start, Respond respond) async {
    await start(statusCode, rawHeaders);
    await respond(body);
  }
}
