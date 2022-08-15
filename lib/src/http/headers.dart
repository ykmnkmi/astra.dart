part of '../../http.dart';

final digitsValidator = RegExp(r'^\d+$');

class Headers extends MapBase<String, List<String>> {
  Headers(this.protocolVersion) : headers = HashMap<String, List<String>>() {
    if (protocolVersion == '1.0') {
      persistent = false;
      chunked = false;
    }
  }

  final String protocolVersion;

  final Map<String, List<String>> headers;

  List<String>? noFoldingHeaders;

  int _contentLength = -1;

  bool persistent = true;

  bool chunked = false;

  String? _host;

  int? _port;

  @override
  List<String>? operator [](Object? key) {
    return headers[key];
  }

  void addValue(String name, String value) {
    _add(name, value);
  }

  void setValue(String name, String value) {
    if (name == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }

    if (name == HttpHeaders.transferEncodingHeader) {
      chunked = false;
    }

    _add(name, value);
  }

  void removeValue(String name, Object value) {
    var values = headers[name];

    if (values != null) {
      values.remove(_valueToString(value));

      if (values.isEmpty) {
        headers.remove(name);
      }
    }

    if (name == HttpHeaders.transferEncodingHeader && value == 'chunked') {
      chunked = false;
    }
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    void forEach(String name, List<String> values) {
      action(name, values);
    }

    headers.forEach(forEach);
  }

  void noFolding(String name) {
    var values = noFoldingHeaders ??= <String>[];
    values.add(name);
  }

  bool get persistentConnection {
    return persistent;
  }

  set persistentConnection(bool persistentConnection) {
    if (persistentConnection == persistent) {
      return;
    }

    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        removeValue(HttpHeaders.connectionHeader, 'close');
      } else {
        if (_contentLength < 0) {
          throw HttpException('Trying to set \'Connection: Keep-Alive\' on HTTP 1.0 headers with no ContentLength');
        }

        addValue(HttpHeaders.connectionHeader, 'keep-alive');
      }
    } else {
      if (protocolVersion == '1.1') {
        addValue(HttpHeaders.connectionHeader, 'close');
      } else {
        removeValue(HttpHeaders.connectionHeader, 'keep-alive');
      }
    }

    persistent = persistentConnection;
  }

  int get contentLength {
    return _contentLength;
  }

  set contentLength(int contentLength) {
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

  @override
  bool get chunkedTransferEncoding => chunked;

  @override
  set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw HttpException("Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }
    if (chunkedTransferEncoding == chunked) return;
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
    chunked = chunkedTransferEncoding;
  }

  @override
  String? get host => _host;

  @override
  set host(String? host) {
    _host = host;
    _updateHostHeader();
  }

  @override
  int? get port => _port;

  @override
  set port(int? port) {
    _port = port;
    _updateHostHeader();
  }

  @override
  DateTime? get ifModifiedSince {
    List<String>? values = headers[HttpHeaders.ifModifiedSinceHeader];
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

  @override
  set ifModifiedSince(DateTime? ifModifiedSince) {
    if (ifModifiedSince == null) {
      headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  @override
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

  @override
  set date(DateTime? date) {
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
    if (expires == null) {
      headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  String? get contentType {
    var values = this[HttpHeaders.contentTypeHeader];

    if (values == null) {
      return null;
    }

    return values.join();
  }

  set contentType(String? contentType) {
    if (contentType == null) {
      headers.remove(HttpHeaders.contentTypeHeader);
    } else {
      _set(HttpHeaders.contentTypeHeader, contentType);
    }
  }

  @override
  void clear() {
    headers.clear();
    _contentLength = -1;
    persistent = true;
    chunked = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, value) {
    assert(name == validateField(name));
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
          _addConnection(name, value);
          return;
        }
        break;
      case 12:
        if (HttpHeaders.contentTypeHeader == name) {
          _addContentType(name, value);
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

  void _addIfModifiedSince(String name, value) {
    if (value is DateTime) {
      ifModifiedSince = value;
    } else if (value is String) {
      _set(HttpHeaders.ifModifiedSinceHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addHost(String name, value) {
    if (value is String) {
      // value.indexOf will only work for ipv4, ipv6 which has multiple : in its
      // host part needs lastIndexOf
      int pos = value.lastIndexOf(':');
      // According to RFC 3986, section 3.2.2, host part of ipv6 address must be
      // enclosed by square brackets.
      // https://serverfault.com/questions/205793/how-can-one-distinguish-the-host-and-the-port-in-an-ipv6-url
      if (pos == -1 || value.startsWith('[') && value.endsWith(']')) {
        _host = value;
        _port = HttpClient.defaultHttpPort;
      } else {
        if (pos > 0) {
          _host = value.substring(0, pos);
        } else {
          _host = null;
        }
        if (pos + 1 == value.length) {
          _port = HttpClient.defaultHttpPort;
        } else {
          try {
            _port = int.parse(value.substring(pos + 1));
          } on FormatException {
            _port = null;
          }
        }
      }
      _set(HttpHeaders.hostHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addConnection(String name, String value) {
    var lowerCaseValue = value.toLowerCase();
    if (lowerCaseValue == 'close') {
      persistent = false;
    } else if (lowerCaseValue == 'keep-alive') {
      persistent = true;
    }
    _addValue(name, value);
  }

  void _addContentType(String name, value) {
    _set(HttpHeaders.contentTypeHeader, value);
  }

  void _addValue(String name, Object value) {
    List<String> values = (headers[name] ??= <String>[]);
    values.add(_valueToString(value));
  }

  String _valueToString(Object value) {
    if (value is DateTime) {
      return HttpDate.format(value);
    } else if (value is String) {
      return value; // TODO(39784): no _validateValue?
    } else {
      return validateValue(value.toString()) as String;
    }
  }

  void _set(String name, String value) {
    assert(name == validateField(name));
    headers[name] = <String>[value];
  }

  void _updateHostHeader() {
    var host = _host;
    if (host != null) {
      bool defaultPort = _port == null || _port == _defaultPortForScheme;
      _set('host', defaultPort ? host : '$host:$_port');
    }
  }

  bool _foldHeader(String name) {
    if (name == HttpHeaders.setCookieHeader) return false;
    var noFoldingHeaders = this.noFoldingHeaders;
    return noFoldingHeaders == null || !noFoldingHeaders.contains(name);
  }

  void _finalize() {
    _mutable = false;
  }

  void _build(BytesBuilder builder, {bool skipZeroContentLength = false}) {
    // per https://tools.ietf.org/html/rfc7230#section-3.3.2
    // A user agent SHOULD NOT send a
    // Content-Length header field when the request message does not
    // contain a payload body and the method semantics do not anticipate
    // such a body.
    String? ignoreHeader = _contentLength == 0 && skipZeroContentLength ? HttpHeaders.contentLengthHeader : null;
    headers.forEach((String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }
      String originalName = originalHeaderName(name);
      bool fold = _foldHeader(name);
      var nameData = originalName.codeUnits;
      builder.add(nameData);
      builder.addByte(_CharCode.COLON);
      builder.addByte(_CharCode.SP);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            builder.addByte(_CharCode.COMMA);
            builder.addByte(_CharCode.SP);
          } else {
            builder.addByte(_CharCode.CR);
            builder.addByte(_CharCode.LF);
            builder.add(nameData);
            builder.addByte(_CharCode.COLON);
            builder.addByte(_CharCode.SP);
          }
        }
        builder.add(values[i].codeUnits);
      }
      builder.addByte(_CharCode.CR);
      builder.addByte(_CharCode.LF);
    });
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    headers.forEach((String name, List<String> values) {
      String originalName = originalHeaderName(name);
      sb
        ..write(originalName)
        ..write(': ');
      bool fold = _foldHeader(name);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            sb.write(', ');
          } else {
            sb
              ..write('\n')
              ..write(originalName)
              ..write(': ');
          }
        }
        sb.write(values[i]);
      }
      sb.write('\n');
    });
    return sb.toString();
  }

  List<Cookie> _parseCookies() {
    // Parse a Cookie header value according to the rules in RFC 6265.
    var cookies = <Cookie>[];
    void parseCookieString(String s) {
      int index = 0;

      bool done() => index == -1 || index == s.length;

      void skipWS() {
        while (!done()) {
          if (s[index] != ' ' && s[index] != '\t') return;
          index++;
        }
      }

      String parseName() {
        int start = index;
        while (!done()) {
          if (s[index] == ' ' || s[index] == '\t' || s[index] == '=') break;
          index++;
        }
        return s.substring(start, index);
      }

      String parseValue() {
        int start = index;
        while (!done()) {
          if (s[index] == ' ' || s[index] == '\t' || s[index] == ';') break;
          index++;
        }
        return s.substring(start, index);
      }

      bool expect(String expected) {
        if (done()) return false;
        if (s[index] != expected) return false;
        index++;
        return true;
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        String name = parseName();
        skipWS();
        if (!expect('=')) {
          index = s.indexOf(';', index);
          continue;
        }
        skipWS();
        String value = parseValue();
        try {
          cookies.add(_Cookie(name, value));
        } catch (_) {
          // Skip it, invalid cookie data.
        }
        skipWS();
        if (done()) return;
        if (!expect(';')) {
          index = s.indexOf(';', index);
          continue;
        }
      }
    }

    List<String>? values = headers[HttpHeaders.cookieHeader];
    if (values != null) {
      for (var headerValue in values) {
        parseCookieString(headerValue);
      }
    }
    return cookies;
  }

  String originalHeaderName(String name) {
    var originalHeaderNames = this.originalHeaderNames;

    if (originalHeaderNames == null) {
      return name;
    }

    return originalHeaderNames[name] ?? name;
  }
}
