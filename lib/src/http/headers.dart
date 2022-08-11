part of '../../http.dart';

final RegExp digitsValidator = RegExp(r'^\d+$');

class Headers {
  Headers(this.protocolVersion, {this.defaultPortForScheme = 80}) : headers = HashMap<String, List<String>>() {
    if (protocolVersion == '1.0') {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  final String protocolVersion;

  final int defaultPortForScheme;

  final Map<String, List<String>> headers;

  bool mutable = true; // Are the headers currently mutable?

  List<String>? noFoldingHeaders;

  int _contentLength = -1;

  bool _persistentConnection = true;

  bool _chunkedTransferEncoding = false;

  String? _host;

  int? _port;

  List<String>? operator [](String name) {
    assert(name == name.toLowerCase());
    validateField(name);
    return headers[name];
  }

  String? value(String name) {
    assert(name == name.toLowerCase());
    validateField(name);

    var values = headers[name];

    if (values == null) {
      return null;
    }

    assert(values.isNotEmpty);

    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }

    return values[0];
  }

  void add(String name, String value) {
    assert(name == name.toLowerCase());
    checkMutable();
    validateField(name);
    _addOne(name, value);
  }

  void _addOne(String name, String value) {
    validateValue(value);
    _add(name, value);
  }

  void _addAll(String name, Iterable<String> values) {
    for (var value in values) {
      validateValue(value);
      _add(name, value);
    }
  }

  void set(String name, String value) {
    checkMutable();
    validateField(name);
    headers.remove(name);

    if (name == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }

    if (name == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }

    _addOne(name, value);
  }

  void remove(String name, String value) {
    checkMutable();
    validateField(name);
    validateValue(value);

    var values = headers[name];

    if (values != null) {
      values.remove(valueToString(value));

      if (values.isEmpty) {
        headers.remove(name);
      }
    }

    if (name == HttpHeaders.transferEncodingHeader && value == 'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  void removeAll(String name) {
    checkMutable();
    validateField(name);
    headers.remove(name);
  }

  void forEach(void Function(String name, List<String> values) action) {
    headers.forEach(action);
  }

  void noFolding(String name) {
    assert(name == name.toLowerCase());
    validateField(name);

    var noFolding = noFoldingHeaders ??= <String>[];
    noFolding.add(name);
  }

  bool get persistentConnection => _persistentConnection;

  set persistentConnection(bool persistentConnection) {
    checkMutable();
    if (persistentConnection == _persistentConnection) return;
    final originalName = _originalHeaderName(HttpHeaders.connectionHeader);
    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        remove(HttpHeaders.connectionHeader, 'close');
      } else {
        if (_contentLength < 0) {
          throw HttpException("Trying to set 'Connection: Keep-Alive' on HTTP 1.0 headers with "
              'no ContentLength');
        }
        add(originalName, 'keep-alive', preserveHeaderCase: true);
      }
    } else {
      if (protocolVersion == '1.1') {
        add(originalName, 'close', preserveHeaderCase: true);
      } else {
        remove(HttpHeaders.connectionHeader, 'keep-alive');
      }
    }
    _persistentConnection = persistentConnection;
  }

  int get contentLength => _contentLength;

  set contentLength(int contentLength) {
    checkMutable();
    if (protocolVersion == '1.0' && persistentConnection && contentLength == -1) {
      throw HttpException('Trying to clear ContentLength on HTTP 1.0 headers with '
          "'Connection: Keep-Alive' set");
    }
    if (_contentLength == contentLength) return;
    _contentLength = contentLength;
    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) chunkedTransferEncoding = false;
      _set(HttpHeaders.contentLengthHeader, contentLength.toString());
    } else {
      headers.remove(HttpHeaders.contentLengthHeader);
      if (protocolVersion == '1.1') {
        chunkedTransferEncoding = true;
      }
    }
  }

  bool get chunkedTransferEncoding => _chunkedTransferEncoding;

  set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    checkMutable();
    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw HttpException("Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }
    if (chunkedTransferEncoding == _chunkedTransferEncoding) return;
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

  String? get host {
    return _host;
  }

  set host(String? host) {
    checkMutable();
    _host = host;
    updateHostHeader();
  }

  int? get port => _port;

  set port(int? port) {
    checkMutable();
    _port = port;
    updateHostHeader();
  }

  DateTime? get ifModifiedSince {
    var values = headers[HttpHeaders.ifModifiedSinceHeader];

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

  DateTime? get date {
    List<String>? values = headers[HttpHeaders.dateHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  set date(DateTime? date) {
    checkMutable();
    if (date == null) {
      headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(date.toUtc());
      _set(HttpHeaders.dateHeader, formatted);
    }
  }

  DateTime? get expires {
    List<String>? values = headers[HttpHeaders.expiresHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  set expires(DateTime? expires) {
    checkMutable();
    if (expires == null) {
      headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  ContentType? get contentType {
    var values = headers[HttpHeaders.contentTypeHeader];
    if (values != null) {
      return ContentType.parse(values[0]);
    } else {
      return null;
    }
  }

  set contentType(ContentType? contentType) {
    checkMutable();
    if (contentType == null) {
      headers.remove(HttpHeaders.contentTypeHeader);
    } else {
      _set(HttpHeaders.contentTypeHeader, contentType.toString());
    }
  }

  void clear() {
    checkMutable();
    headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, String value) {
    assert(name == name.toLowerCase());

    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          _addDate(name, value);
          return;
        }

        if (HttpHeaders.hostHeader == name) {
          _addHost(name, value);
          return;
        }

        break;
      case 7:
        if (HttpHeaders.expiresHeader == name) {
          _addExpires(name, value);
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
          addContentType(name, value);
          return;
        }

        break;
      case 14:
        if (HttpHeaders.contentLengthHeader == name) {
          _addContentLength(name, value);
          return;
        }

        break;
      case 17:
        if (HttpHeaders.transferEncodingHeader == name) {
          _addTransferEncoding(name, value);
          return;
        }

        if (HttpHeaders.ifModifiedSinceHeader == name) {
          _addIfModifiedSince(name, value);
          return;
        }
    }

    _addValue(name, value);
  }

  void _addContentLength(String name, value) {
    if (value is int) {
      if (value < 0) {
        throw HttpException('Content-Length must contain only digits');
      }
    } else if (value is String) {
      if (!digitsValidator.hasMatch(value)) {
        throw HttpException('Content-Length must contain only digits');
      }
      value = int.parse(value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
    contentLength = value;
  }

  void _addTransferEncoding(String name, value) {
    if (value == 'chunked') {
      chunkedTransferEncoding = true;
    } else {
      _addValue(HttpHeaders.transferEncodingHeader, value);
    }
  }

  void _addDate(String name, value) {
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      _set(HttpHeaders.dateHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addExpires(String name, value) {
    if (value is DateTime) {
      expires = value;
    } else if (value is String) {
      _set(HttpHeaders.expiresHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addIfModifiedSince(String name, String value) {
    if (value is DateTime) {
      ifModifiedSince = value;
    } else if (value is String) {
      _set(HttpHeaders.ifModifiedSinceHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addHost(String name, String value) {
    // value.indexOf will only work for ipv4, ipv6 which has multiple : in its
    // host part needs lastIndexOf
    var pos = value.lastIndexOf(':');

    // According to RFC 3986, section 3.2.2, host part of ipv6 address must be
    // enclosed by square brackets.
    // https://serverfault.com/questions/205793/how-can-one-distinguish-the-host-and-the-port-in-an-ipv6-url
    if (pos == -1 || value.startsWith('[') && value.endsWith(']')) {
      _host = value;
      _port = 80;
    } else {
      if (pos > 0) {
        _host = value.substring(0, pos);
      } else {
        _host = null;
      }
      if (pos + 1 == value.length) {
        _port = 80;
      } else {
        try {
          _port = int.parse(value.substring(pos + 1));
        } on FormatException {
          _port = null;
        }
      }
    }

    _set(HttpHeaders.hostHeader, value);
  }

  void addConnection(String name, String value) {
    var lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }

    _addValue(name, value);
  }

  void addContentType(String name, String value) {
    _set(HttpHeaders.contentTypeHeader, value);
  }

  void _addValue(String name, String value) {
    var values = headers[name] ??= <String>[];
    values.add(value);
  }

  void _set(String name, String value) {
    headers[name] = <String>[value];
  }

  void checkMutable() {
    if (mutable) {
      return;
    }

    throw HttpException('HTTP headers are not mutable');
  }

  void updateHostHeader() {
    var host = _host;

    if (host != null) {
      var defaultPort = _port == null || _port == defaultPortForScheme;
      _set('host', defaultPort ? host : '$host:$_port');
    }
  }

  bool foldHeader(String name) {
    if (name == HttpHeaders.setCookieHeader) {
      return false;
    }

    var noFoldingHeaders = this.noFoldingHeaders;
    return noFoldingHeaders == null || !noFoldingHeaders.contains(name);
  }

  void finalize() {
    mutable = false;
  }

  void build(BytesBuilder builder, {bool skipZeroContentLength = false}) {
    // per https://tools.ietf.org/html/rfc7230#section-3.3.2
    // A user agent SHOULD NOT send a
    // Content-Length header field when the request message does not
    // contain a payload body and the method semantics do not anticipate
    // such a body.
    var ignoreHeader = _contentLength == 0 && skipZeroContentLength ? HttpHeaders.contentLengthHeader : null;

    void forEach(String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }

      var fold = foldHeader(name);
      var nameData = name.codeUnits;
      builder.add(nameData);
      builder.addByte(CharCodes.colon);
      builder.addByte(CharCodes.sp);

      for (var index = 0; index < values.length; index++) {
        if (index > 0) {
          if (fold) {
            builder.addByte(CharCodes.comma);
            builder.addByte(CharCodes.sp);
          } else {
            builder.addByte(CharCodes.cr);
            builder.addByte(CharCodes.lf);
            builder.add(nameData);
            builder.addByte(CharCodes.colon);
            builder.addByte(CharCodes.sp);
          }
        }

        builder.add(values[index].codeUnits);
      }

      builder.addByte(CharCodes.cr);
      builder.addByte(CharCodes.lf);
    }

    headers.forEach(forEach);
  }

  @override
  String toString() {
    var buffer = StringBuffer();

    headers.forEach((String name, List<String> values) {
      var fold = foldHeader(name);

      buffer
        ..write(name)
        ..write(': ');

      for (int index = 0; index < values.length; index++) {
        if (index > 0) {
          if (fold) {
            buffer.write(', ');
          } else {
            buffer
              ..write('\n')
              ..write(name)
              ..write(': ');
          }
        }

        buffer.write(values[index]);
      }

      buffer.write('\n');
    });

    return buffer.toString();
  }

  static void validateField(String field) {
    for (var i = 0; i < field.length; i++) {
      if (Parser.isTokenChar(field.codeUnitAt(i))) {
        continue;
      }

      throw FormatException('Invalid HTTP header field name: ${json.encode(field)}', field, i);
    }
  }

  static void validateValue(String value) {
    for (var i = 0; i < (value).length; i++) {
      if (Parser.isValueChar((value).codeUnitAt(i))) {
        continue;
      }

      throw FormatException('Invalid HTTP header field value: ${json.encode(value)}', value, i);
    }
  }
}
