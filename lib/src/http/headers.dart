// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show HashMap;
import 'dart:convert' show json;
import 'dart:io' show ContentType, HttpDate, HttpException, HttpHeaders;

import 'dart:typed_data' show BytesBuilder;

import 'package:astra/src/http/parser.dart';

final RegExp digitsValidator = RegExp(r'^\d+$');

class NativeHeaders {
  NativeHeaders(this.protocolVersion, {this.defaultPortForScheme = 80, NativeHeaders? initialHeaders})
      : headers = HashMap<String, List<String>>() {
    if (initialHeaders != null) {
      void action(String name, List<String> value) {
        headers[name] = value;
      }

      initialHeaders.headers.forEach(action);
      _contentLength = initialHeaders._contentLength;
      _persistentConnection = initialHeaders._persistentConnection;
      _chunkedTransferEncoding = initialHeaders._chunkedTransferEncoding;
    }

    if (protocolVersion == '1.0') {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  final String protocolVersion;

  final int defaultPortForScheme;

  final Map<String, List<String>> headers;

  List<String>? noFoldingHeaders;

  int _contentLength = -1;

  bool _persistentConnection = true;

  bool _chunkedTransferEncoding = false;

  bool get persistentConnection {
    return _persistentConnection;
  }

  set persistentConnection(bool persistentConnection) {
    if (persistentConnection == _persistentConnection) {
      return;
    }

    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        remove(HttpHeaders.connectionHeader, 'close');
      } else {
        if (_contentLength < 0) {
          throw HttpException("Trying to set 'Connection: Keep-Alive' on HTTP 1.0 headers with no ContentLength");
        }

        add(HttpHeaders.connectionHeader, 'keep-alive');
      }
    } else {
      if (protocolVersion == '1.1') {
        add(HttpHeaders.connectionHeader, 'close');
      } else {
        remove(HttpHeaders.connectionHeader, 'keep-alive');
      }
    }

    _persistentConnection = persistentConnection;
  }

  int get contentLength {
    return _contentLength;
  }

  set contentLength(int contentLength) {
    if (protocolVersion == '1.0' && persistentConnection && contentLength == -1) {
      throw HttpException("Trying to clear ContentLength on HTTP 1.0 headers with 'Connection: Keep-Alive' set");
    }

    if (_contentLength == contentLength) {
      return;
    }

    _contentLength = contentLength;

    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) {
        chunkedTransferEncoding = false;
      }

      _setValue(HttpHeaders.contentLengthHeader, '$contentLength');
    } else {
      headers.remove(HttpHeaders.contentLengthHeader);

      if (protocolVersion == '1.1') {
        chunkedTransferEncoding = true;
      }
    }
  }

  bool get chunkedTransferEncoding {
    return _chunkedTransferEncoding;
  }

  set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw HttpException("Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }

    if (chunkedTransferEncoding == _chunkedTransferEncoding) {
      return;
    }

    if (chunkedTransferEncoding) {
      List<String>? values = headers[HttpHeaders.transferEncodingHeader];

      if (values == null || !values.contains('chunked')) {
        // Headers does not specify chunked encoding - add it if set.
        _addValue(HttpHeaders.transferEncodingHeader, 'chunked');
      }

      contentLength = -1;
    } else {
      // Headers does specify chunked encoding - remove it if not set.
      remove(HttpHeaders.transferEncodingHeader, 'chunked');
    }

    _chunkedTransferEncoding = chunkedTransferEncoding;
  }

  DateTime? get ifModifiedSince {
    List<String>? values = headers[HttpHeaders.ifModifiedSinceHeader];

    if (values == null) {
      return null;
    }

    assert(values.isNotEmpty);

    try {
      return HttpDate.parse(values[0]);
    } on Exception {
      return null;
    }
  }

  set ifModifiedSince(DateTime? ifModifiedSince) {
    if (ifModifiedSince == null) {
      headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(ifModifiedSince.toUtc());
      _setValue(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  DateTime? get date {
    List<String>? values = headers[HttpHeaders.dateHeader];

    if (values == null) {
      return null;
    }

    assert(values.isNotEmpty);

    try {
      return HttpDate.parse(values[0]);
    } on Exception {
      return null;
    }
  }

  set date(DateTime? date) {
    if (date == null) {
      headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(date.toUtc());
      _setValue(HttpHeaders.dateHeader, formatted);
    }
  }

  DateTime? get expires {
    List<String>? values = headers[HttpHeaders.expiresHeader];

    if (values == null) {
      return null;
    }

    assert(values.isNotEmpty);

    try {
      return HttpDate.parse(values[0]);
    } on Exception {
      return null;
    }
  }

  ContentType? get contentType {
    List<String>? values = headers[HttpHeaders.contentTypeHeader];

    if (values == null) {
      return null;
    }

    return ContentType.parse(values[0]);
  }

  List<String>? operator [](String name) {
    return headers[validateField(name)];
  }

  void add(String name, String value) {
    addValue(validateField(name), validateValue(value));
  }

  void addAll(String name, Iterable<String> values) {
    for (String value in values) {
      add(name, value);
    }
  }

  void set(String name, String value) {
    String lowercaseName = validateField(name);
    headers.remove(lowercaseName);

    if (lowercaseName == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }

    if (lowercaseName == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }

    addValue(lowercaseName, validateValue(value));
  }

  void setAll(String name, List<String> values) {
    String lowercaseName = validateField(name);
    headers.remove(lowercaseName);

    if (lowercaseName == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }

    for (String value in values) {
      addValue(lowercaseName, validateValue(value));
    }
  }

  void remove(String name, String value) {
    name = validateField(name);
    value = validateValue(value);

    List<String>? values = headers[name];

    if (values != null) {
      values.remove(value);

      if (values.isEmpty) {
        headers.remove(name);
      }
    }

    if (name == HttpHeaders.transferEncodingHeader && value == 'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  void removeAll(String name) {
    name = validateField(name);
    headers.remove(name);
  }

  void forEach(void Function(String name, List<String> values) action) {
    headers.forEach(action);
  }

  void noFolding(String name) {
    name = validateField(name);

    List<String> list = noFoldingHeaders ??= <String>[];
    list.add(name);
  }

  void clear() {
    headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
  }

  void addValue(String name, String value) {
    assert(name == validateField(name));
    assert(value == validateValue(value));

    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          _setValue(HttpHeaders.dateHeader, value);
          return;
        }

        if (HttpHeaders.hostHeader == name) {
          _setValue(HttpHeaders.hostHeader, value);
          return;
        }

        break;

      case 7:
        if (HttpHeaders.expiresHeader == name) {
          _setValue(HttpHeaders.expiresHeader, value);
          return;
        }

        break;

      case 10:
        if (HttpHeaders.connectionHeader == name) {
          addConnection(name, value);
          return;
        }

        break;

      case 12:
        if (HttpHeaders.contentTypeHeader == name) {
          _setValue(HttpHeaders.contentTypeHeader, value);
          return;
        }

        break;

      case 14:
        if (HttpHeaders.contentLengthHeader == name) {
          if (digitsValidator.hasMatch(value)) {
            contentLength = int.parse(value);
            return;
          }

          throw HttpException('Content-Length must contain only digits');
        }

        break;

      case 17:
        if (HttpHeaders.transferEncodingHeader == name) {
          if (value == 'chunked') {
            chunkedTransferEncoding = true;
          } else {
            _addValue(HttpHeaders.transferEncodingHeader, value);
          }

          return;
        }

        if (HttpHeaders.ifModifiedSinceHeader == name) {
          _setValue(HttpHeaders.ifModifiedSinceHeader, value);
          return;
        }
    }

    _addValue(name, value);
  }

  void addConnection(String name, String value) {
    String lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }

    _addValue(name, value);
  }

  void _addValue(String name, String value) {
    List<String> values = headers[name] ??= <String>[];
    values.add(value);
  }

  void _setValue(String name, String value) {
    headers[name] = <String>[value];
  }

  bool foldHeader(String name) {
    if (name == HttpHeaders.setCookieHeader) {
      return false;
    }

    List<String>? headers = noFoldingHeaders;
    return headers == null || !headers.contains(name);
  }

  void build(BytesBuilder builder, {bool skipZeroContentLength = false}) {
    // per https://tools.ietf.org/html/rfc7230#section-3.3.2
    // A user agent SHOULD NOT send a
    // Content-Length header field when the request message does not
    // contain a payload body and the method semantics do not anticipate
    // such a body.
    String? ignoreHeader = _contentLength == 0 && skipZeroContentLength ? HttpHeaders.contentLengthHeader : null;

    void action(String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }

      bool fold = foldHeader(name);
      List<int> nameData = name.codeUnits;

      builder
        ..add(nameData)
        ..addByte(CharCode.colon)
        ..addByte(CharCode.sp);

      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            builder
              ..addByte(CharCode.comma)
              ..addByte(CharCode.sp);
          } else {
            builder
              ..addByte(CharCode.cr)
              ..addByte(CharCode.lf)
              ..add(nameData)
              ..addByte(CharCode.colon)
              ..addByte(CharCode.sp);
          }
        }

        builder.add(values[i].codeUnits);
      }

      builder
        ..addByte(CharCode.cr)
        ..addByte(CharCode.lf);
    }

    headers.forEach(action);
  }

  @override
  String toString() {
    StringBuffer stringBuffer = StringBuffer();

    void action(String name, List<String> values) {
      stringBuffer
        ..write(name)
        ..write(': ');

      bool fold = foldHeader(name);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            stringBuffer.write(', ');
          } else {
            stringBuffer
              ..write('\n')
              ..write(name)
              ..write(': ');
          }
        }

        stringBuffer.write(values[i]);
      }

      stringBuffer.write('\n');
    }

    headers.forEach(action);
    return '$stringBuffer';
  }

  static String validateField(String field) {
    for (int i = 0; i < field.length; i += 1) {
      if (!Parser.isTokenChar(field.codeUnitAt(i))) {
        throw FormatException('Invalid HTTP header field name: ${json.encode(field)}', field, i);
      }
    }
    return field.toLowerCase();
  }

  static String validateValue(String value) {
    for (int i = 0; i < value.length; i += 1) {
      if (!Parser.isValueChar(value.codeUnitAt(i))) {
        throw FormatException('Invalid HTTP header field value: ${json.encode(value)}', value, i);
      }
    }

    return value;
  }
}
