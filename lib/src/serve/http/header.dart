part of astra.serve.http;

class Headers {
  final String protocolVersion;

  final int defaultPortForScheme;

  final Map<String, List<String>> headers;

  Headers(this.protocolVersion, //
      {this.defaultPortForScheme = HttpClient.defaultHttpPort,
      Headers? initialHeaders})
      : headers = HashMap<String, List<String>>() {
    if (initialHeaders != null) {
      initialHeaders.headers.forEach((name, value) => headers[name] = value);
      _contentLength = initialHeaders._contentLength;
      _persistentConnection = initialHeaders._persistentConnection;
      _chunkedTransferEncoding = initialHeaders._chunkedTransferEncoding;
      _host = initialHeaders._host;
      _port = initialHeaders._port;
    }

    if (protocolVersion == '1.0') {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  Map<String, String>? originalHeaderNames;

  bool mutable = true; // Are the headers currently mutable?

  List<String>? _noFoldingHeaders;

  int _contentLength = -1;

  bool _persistentConnection = true;

  bool _chunkedTransferEncoding = false;

  String? _host;

  int? _port;

  List<String>? operator [](String name) {
    return headers[validateField(name)];
  }

  void add(String name, String value, {bool preserveHeaderCase = false}) {
    checkMutable();

    var lowercaseName = validateField(name);

    if (preserveHeaderCase && name != lowercaseName) {
      (originalHeaderNames ??= {})[lowercaseName] = name;
    } else {
      originalHeaderNames?.remove(lowercaseName);
    }

    addValue(name, validateValue(value));
  }

  void set(String name, String value, {bool preserveHeaderCase = false}) {
    checkMutable();

    var lowercaseName = validateField(name);
    headers.remove(lowercaseName);
    originalHeaderNames?.remove(lowercaseName);

    if (lowercaseName == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }

    if (lowercaseName == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }

    if (preserveHeaderCase && name != lowercaseName) {
      (originalHeaderNames ??= {})[lowercaseName] = name;
    }

    addValue(name, validateValue(value));
  }

  String? value(String name) {
    name = validateField(name);
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

  void remove(String name, String value) {
    checkMutable();
    name = validateField(name);
    value = validateValue(value);

    var values = headers[name];

    if (values != null) {
      values.remove(value);

      if (values.isEmpty) {
        headers.remove(name);
        originalHeaderNames?.remove(name);
      }
    }

    if (name == HttpHeaders.transferEncodingHeader && value == 'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  void removeAll(String name) {
    checkMutable();
    name = validateField(name);
    headers.remove(name);
    originalHeaderNames?.remove(name);
  }

  void forEach(void Function(String name, List<String> values) action) {
    headers.forEach((String name, List<String> values) {
      action(originalHeaderName(name), values);
    });
  }

  void noFolding(String name) {
    var values = _noFoldingHeaders ??= <String>[];
    values.add(validateField(name));
  }

  bool get persistentConnection {
    return _persistentConnection;
  }

  set persistentConnection(bool persistentConnection) {
    checkMutable();

    if (persistentConnection == _persistentConnection) {
      return;
    }

    var originalName = originalHeaderName(HttpHeaders.connectionHeader);

    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        remove(HttpHeaders.connectionHeader, 'close');
      } else {
        if (_contentLength < 0) {
          throw HttpException(
              'Trying to set \'Connection: Keep-Alive\' on HTTP 1.0 headers with no ContentLength');
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

  int get contentLength {
    return _contentLength;
  }

  set contentLength(int contentLength) {
    checkMutable();

    if (protocolVersion == '1.0' && persistentConnection && contentLength == -1) {
      throw HttpException(
          'Trying to clear ContentLength on HTTP 1.0 headers with \'Connection: Keep-Alive\' set.');
    }

    if (_contentLength == contentLength) {
      return;
    }

    _contentLength = contentLength;

    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) {
        chunkedTransferEncoding = false;
      }

      _set(HttpHeaders.contentLengthHeader, contentLength.toString());
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
    checkMutable();

    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw HttpException("Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }

    if (chunkedTransferEncoding == _chunkedTransferEncoding) {
      return;
    }

    if (chunkedTransferEncoding) {
      var values = headers[HttpHeaders.transferEncodingHeader];

      if (values == null || !values.contains('chunked')) {
        // Headers does not specify chunked encoding - add it if set.
        _add(HttpHeaders.transferEncodingHeader, 'chunked');
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

  int? get port {
    return _port;
  }

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

  set ifModifiedSince(DateTime? ifModifiedSince) {
    checkMutable();

    if (ifModifiedSince == null) {
      headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  DateTime? get date {
    var values = headers[HttpHeaders.dateHeader];

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
    checkMutable();

    if (date == null) {
      headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(date.toUtc());
      _set(HttpHeaders.dateHeader, formatted);
    }
  }

  DateTime? get expires {
    var values = headers[HttpHeaders.expiresHeader];

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

  set expires(DateTime? expires) {
    checkMutable();

    if (expires == null) {
      headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  ContentType? get contentType {
    var values = headers[HttpHeaders.contentTypeHeader];

    if (values != null) {
      return ContentType.parse(values[0]);
    }

    return null;
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
  void addValue(String name, String value) {
    assert(name == validateField(name));

    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          addDate(name, value);
          return;
        }

        if (HttpHeaders.hostHeader == name) {
          addHost(name, value);
          return;
        }

        break;

      case 7:
        if (HttpHeaders.expiresHeader == name) {
          addExpires(name, value);
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
          addContentLength(name, value);
          return;
        }

        break;

      case 17:
        if (HttpHeaders.transferEncodingHeader == name) {
          addTransferEncoding(name, value);
          return;
        }

        if (HttpHeaders.ifModifiedSinceHeader == name) {
          addIfModifiedSince(name, value);
          return;
        }
    }

    _add(name, value);
  }

  void addContentLength(String name, String value) {
    contentLength = int.parse(value);
  }

  void addTransferEncoding(String name, String value) {
    if (value == 'chunked') {
      chunkedTransferEncoding = true;
    } else {
      _add(HttpHeaders.transferEncodingHeader, value);
    }
  }

  void addDate(String name, String value) {
    _set(HttpHeaders.dateHeader, value);
  }

  void addExpires(String name, String value) {
    _set(HttpHeaders.expiresHeader, value);
  }

  void addIfModifiedSince(String name, String value) {
    _set(HttpHeaders.ifModifiedSinceHeader, value);
  }

  void addHost(String name, String value) {
    // value.indexOf will only work for ipv4, ipv6 which has multiple : in its
    // host part needs lastIndexOf
    var position = value.lastIndexOf(':');

    // According to RFC 3986, section 3.2.2, host part of ipv6 address must be
    // enclosed by square brackets.
    // https://serverfault.com/questions/205793/how-can-one-distinguish-the-host-and-the-port-in-an-ipv6-url
    if (position == -1 || value.startsWith('[') && value.endsWith(']')) {
      _host = value;
      _port = HttpClient.defaultHttpPort;
    } else {
      if (position > 0) {
        _host = value.substring(0, position);
      } else {
        _host = null;
      }
      if (position + 1 == value.length) {
        _port = HttpClient.defaultHttpPort;
      } else {
        try {
          _port = int.parse(value.substring(position + 1));
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

    _add(name, value);
  }

  void addContentType(String name, String value) {
    _set(HttpHeaders.contentTypeHeader, value);
  }

  void _add(String name, String value) {
    var values = headers[name] ??= <String>[];
    values.add(value);
  }

  void _set(String name, String value) {
    assert(name == validateField(name));
    headers[name] = <String>[value];
  }

  void checkMutable() {
    if (!mutable) {
      throw HttpException('HTTP headers are not mutable');
    }
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

    var noFoldingHeaders = _noFoldingHeaders;
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
    var ignoreHeader =
        _contentLength == 0 && skipZeroContentLength ? HttpHeaders.contentLengthHeader : null;

    headers.forEach((String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }

      var originalName = originalHeaderName(name);
      var fold = foldHeader(name);
      var nameData = originalName.codeUnits;

      builder
        ..add(nameData)
        ..addByte(CharCodes.colon)
        ..addByte(CharCodes.sp);

      for (int i = 0; i < values.length; i += 1) {
        if (i > 0) {
          if (fold) {
            builder
              ..addByte(CharCodes.comma)
              ..addByte(CharCodes.sp);
          } else {
            builder
              ..addByte(CharCodes.cr)
              ..addByte(CharCodes.lf)
              ..add(nameData)
              ..addByte(CharCodes.colon)
              ..addByte(CharCodes.sp);
          }
        }

        builder.add(values[i].codeUnits);
      }

      builder
        ..addByte(CharCodes.cr)
        ..addByte(CharCodes.lf);
    });
  }

  @override
  String toString() {
    var buffer = StringBuffer();

    headers.forEach((String name, List<String> values) {
      var originalName = originalHeaderName(name);

      buffer
        ..write(originalName)
        ..write(': ');

      var fold = foldHeader(name);

      for (var index = 0; index < values.length; index += 1) {
        if (index > 0) {
          if (fold) {
            buffer.write(', ');
          } else {
            buffer
              ..write('\n')
              ..write(originalName)
              ..write(': ');
          }
        }

        buffer.write(values[index]);
      }

      buffer.write('\n');
    });

    return buffer.toString();
  }

  static String validateField(String field) {
    for (var index = 0; index < field.length; index += 1) {
      if (!Parser.isTokenChar(field.codeUnitAt(index))) {
        field = json.encode(field);
        throw FormatException('Invalid HTTP header field name: $field', field, index);
      }
    }

    return field.toLowerCase();
  }

  static String validateValue(String value) {
    for (var index = 0; index < (value).length; index += 1) {
      if (!Parser.isValueChar((value).codeUnitAt(index))) {
        value = json.encode(value);
        throw FormatException('Invalid HTTP header field value: $value', value, index);
      }
    }

    return value;
  }

  String originalHeaderName(String name) {
    return originalHeaderNames?[name] ?? name;
  }
}
