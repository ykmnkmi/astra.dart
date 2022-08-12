part of '../../http.dart';

final _digitsValidator = RegExp(r'^\d+$');

class NativeHeaders implements AstraHeaders {
  final Map<String, List<String>> _headers;
  // The original header names keyed by the lowercase header names.
  Map<String, String>? _originalHeaderNames;
  final String protocolVersion;

  bool _mutable = true; // Are the headers currently mutable?
  List<String>? _noFoldingHeaders;

  int _contentLength = -1;
  bool _persistentConnection = true;
  bool _chunkedTransferEncoding = false;
  String? _host;
  int? _port;

  final int _defaultPortForScheme;

  NativeHeaders(this.protocolVersion, {int defaultPortForScheme = 80, NativeHeaders? initialHeaders})
      : _headers = HashMap<String, List<String>>(),
        _defaultPortForScheme = defaultPortForScheme {
    if (initialHeaders != null) {
      initialHeaders._headers.forEach((name, value) => _headers[name] = value);
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

  @override
  List<String>? operator [](String name) => _headers[_validateField(name)];

  @override
  String? value(String name) {
    name = _validateField(name);
    List<String>? values = _headers[name];
    if (values == null) return null;
    assert(values.isNotEmpty);
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values[0];
  }

  @override
  void add(String name, value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    String lowercaseName = _validateField(name);

    if (preserveHeaderCase && name != lowercaseName) {
      (_originalHeaderNames ??= {})[lowercaseName] = name;
    } else {
      _originalHeaderNames?.remove(lowercaseName);
    }
    _addAll(lowercaseName, value);
  }

  void _addAll(String name, Object value) {
    if (value is Iterable<Object>) {
      for (var v in value) {
        _add(name, _validateValue(v));
      }
    } else {
      _add(name, _validateValue(value));
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    String lowercaseName = _validateField(name);
    _headers.remove(lowercaseName);
    _originalHeaderNames?.remove(lowercaseName);
    if (lowercaseName == AstraHeaders.contentLengthHeader) {
      _contentLength = -1;
    }
    if (lowercaseName == AstraHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }
    if (preserveHeaderCase && name != lowercaseName) {
      (_originalHeaderNames ??= {})[lowercaseName] = name;
    }
    _addAll(lowercaseName, value);
  }

  @override
  void remove(String name, Object value) {
    _checkMutable();
    name = _validateField(name);
    value = _validateValue(value);
    List<String>? values = _headers[name];
    if (values != null) {
      values.remove(_valueToString(value));
      if (values.isEmpty) {
        _headers.remove(name);
        _originalHeaderNames?.remove(name);
      }
    }
    if (name == AstraHeaders.transferEncodingHeader && value == 'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  @override
  void removeAll(String name) {
    _checkMutable();
    name = _validateField(name);
    _headers.remove(name);
    _originalHeaderNames?.remove(name);
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach((String name, List<String> values) {
      String originalName = _originalHeaderName(name);
      action(originalName, values);
    });
  }

  @override
  void noFolding(String name) {
    name = _validateField(name);
    (_noFoldingHeaders ??= <String>[]).add(name);
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  void set persistentConnection(bool persistentConnection) {
    _checkMutable();
    if (persistentConnection == _persistentConnection) return;
    final originalName = _originalHeaderName(AstraHeaders.connectionHeader);
    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        remove(AstraHeaders.connectionHeader, 'close');
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
        remove(AstraHeaders.connectionHeader, 'keep-alive');
      }
    }
    _persistentConnection = persistentConnection;
  }

  @override
  int get contentLength => _contentLength;

  @override
  void set contentLength(int contentLength) {
    _checkMutable();
    if (protocolVersion == '1.0' && persistentConnection && contentLength == -1) {
      throw HttpException('Trying to clear ContentLength on HTTP 1.0 headers with '
          "'Connection: Keep-Alive' set");
    }
    if (_contentLength == contentLength) return;
    _contentLength = contentLength;
    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) chunkedTransferEncoding = false;
      _set(AstraHeaders.contentLengthHeader, contentLength.toString());
    } else {
      _headers.remove(AstraHeaders.contentLengthHeader);
      if (protocolVersion == '1.1') {
        chunkedTransferEncoding = true;
      }
    }
  }

  @override
  bool get chunkedTransferEncoding => _chunkedTransferEncoding;

  @override
  void set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    _checkMutable();
    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw HttpException("Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }
    if (chunkedTransferEncoding == _chunkedTransferEncoding) return;
    if (chunkedTransferEncoding) {
      List<String>? values = _headers[AstraHeaders.transferEncodingHeader];
      if (values == null || !values.contains('chunked')) {
        // Headers does not specify chunked encoding - add it if set.
        _addValue(AstraHeaders.transferEncodingHeader, 'chunked');
      }
      contentLength = -1;
    } else {
      // Headers does specify chunked encoding - remove it if not set.
      remove(AstraHeaders.transferEncodingHeader, 'chunked');
    }
    _chunkedTransferEncoding = chunkedTransferEncoding;
  }

  @override
  String? get host => _host;

  @override
  void set host(String? host) {
    _checkMutable();
    _host = host;
    _updateHostHeader();
  }

  @override
  int? get port => _port;

  @override
  void set port(int? port) {
    _checkMutable();
    _port = port;
    _updateHostHeader();
  }

  @override
  DateTime? get ifModifiedSince {
    List<String>? values = _headers[AstraHeaders.ifModifiedSinceHeader];
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
  void set ifModifiedSince(DateTime? ifModifiedSince) {
    _checkMutable();
    if (ifModifiedSince == null) {
      _headers.remove(AstraHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(AstraHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  @override
  DateTime? get date {
    List<String>? values = _headers[AstraHeaders.dateHeader];
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
  void set date(DateTime? date) {
    _checkMutable();
    if (date == null) {
      _headers.remove(AstraHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(date.toUtc());
      _set(AstraHeaders.dateHeader, formatted);
    }
  }

  @override
  DateTime? get expires {
    List<String>? values = _headers[AstraHeaders.expiresHeader];
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
  void set expires(DateTime? expires) {
    _checkMutable();
    if (expires == null) {
      _headers.remove(AstraHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      String formatted = HttpDate.format(expires.toUtc());
      _set(AstraHeaders.expiresHeader, formatted);
    }
  }

  @override
  ContentType? get contentType {
    var values = _headers[AstraHeaders.contentTypeHeader];
    if (values != null) {
      return ContentType.parse(values[0]);
    } else {
      return null;
    }
  }

  @override
  void set contentType(ContentType? contentType) {
    _checkMutable();
    if (contentType == null) {
      _headers.remove(AstraHeaders.contentTypeHeader);
    } else {
      _set(AstraHeaders.contentTypeHeader, contentType.toString());
    }
  }

  @override
  void clear() {
    _checkMutable();
    _headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, Object value) {
    assert(name == _validateField(name));
    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (AstraHeaders.dateHeader == name) {
          _addDate(name, value);
          return;
        }
        if (AstraHeaders.hostHeader == name) {
          _addHost(name, value);
          return;
        }
        break;
      case 7:
        if (AstraHeaders.expiresHeader == name) {
          _addExpires(name, value);
          return;
        }
        break;
      case 10:
        if (AstraHeaders.connectionHeader == name) {
          _addConnection(name, value as String);
          return;
        }
        break;
      case 12:
        if (AstraHeaders.contentTypeHeader == name) {
          _addContentType(name, value as String);
          return;
        }
        break;
      case 14:
        if (AstraHeaders.contentLengthHeader == name) {
          _addContentLength(name, value);
          return;
        }
        break;
      case 17:
        if (AstraHeaders.transferEncodingHeader == name) {
          _addTransferEncoding(name, value);
          return;
        }
        if (AstraHeaders.ifModifiedSinceHeader == name) {
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
      if (!_digitsValidator.hasMatch(value)) {
        throw HttpException('Content-Length must contain only digits');
      }
      value = int.parse(value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
    contentLength = value;
  }

  void _addTransferEncoding(String name, Object value) {
    if (value == 'chunked') {
      chunkedTransferEncoding = true;
    } else {
      _addValue(AstraHeaders.transferEncodingHeader, value);
    }
  }

  void _addDate(String name, Object value) {
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      _set(AstraHeaders.dateHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addExpires(String name, Object value) {
    if (value is DateTime) {
      expires = value;
    } else if (value is String) {
      _set(AstraHeaders.expiresHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addIfModifiedSince(String name, Object value) {
    if (value is DateTime) {
      ifModifiedSince = value;
    } else if (value is String) {
      _set(AstraHeaders.ifModifiedSinceHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addHost(String name, Object value) {
    if (value is String) {
      // value.indexOf will only work for ipv4, ipv6 which has multiple : in its
      // host part needs lastIndexOf
      int pos = value.lastIndexOf(':');
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

      _set(AstraHeaders.hostHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addConnection(String name, String value) {
    var lowerCaseValue = value.toLowerCase();
    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }
    _addValue(name, value);
  }

  void _addContentType(String name, String value) {
    _set(AstraHeaders.contentTypeHeader, value);
  }

  void _addValue(String name, Object value) {
    var values = (_headers[name] ??= <String>[]);
    values.add(_valueToString(value));
  }

  String _valueToString(Object value) {
    if (value is DateTime) {
      return HttpDate.format(value);
    }

    if (value is String) {
      return value; // TODO(39784): no _validateValue?
    }

    return _validateValue(value.toString()) as String;
  }

  void _set(String name, String value) {
    assert(name == _validateField(name));
    _headers[name] = <String>[value];
  }

  void _checkMutable() {
    if (!_mutable) throw HttpException('HTTP headers are not mutable');
  }

  void _updateHostHeader() {
    var host = _host;
    if (host != null) {
      bool defaultPort = _port == null || _port == _defaultPortForScheme;
      _set('host', defaultPort ? host : '$host:$_port');
    }
  }

  bool _foldHeader(String name) {
    if (name == AstraHeaders.setCookieHeader) return false;
    var noFoldingHeaders = _noFoldingHeaders;
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
    String? ignoreHeader = _contentLength == 0 && skipZeroContentLength ? AstraHeaders.contentLengthHeader : null;
    _headers.forEach((String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }
      String originalName = _originalHeaderName(name);
      bool fold = _foldHeader(name);
      var nameData = originalName.codeUnits;
      builder.add(nameData);
      builder.addByte(CharCodes.colon);
      builder.addByte(CharCodes.sp);
      for (int i = 0; i < values.length; i++) {
        if (i > 0) {
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
        builder.add(values[i].codeUnits);
      }
      builder.addByte(CharCodes.cr);
      builder.addByte(CharCodes.lf);
    });
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    _headers.forEach((String name, List<String> values) {
      String originalName = _originalHeaderName(name);
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

  static String _validateField(String field) {
    for (var i = 0; i < field.length; i++) {
      if (!Parser.isTokenChar(field.codeUnitAt(i))) {
        throw FormatException('Invalid HTTP header field name: ${json.encode(field)}', field, i);
      }
    }
    return field.toLowerCase();
  }

  static Object _validateValue(Object value) {
    if (value is! String) return value;
    for (var i = 0; i < (value).length; i++) {
      if (!Parser.isValueChar((value).codeUnitAt(i))) {
        throw FormatException('Invalid HTTP header field value: ${json.encode(value)}', value, i);
      }
    }
    return value;
  }

  String _originalHeaderName(String name) {
    return _originalHeaderNames?[name] ?? name;
  }
}
