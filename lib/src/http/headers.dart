part of '../../http.dart';

final digitsValidator = RegExp(r'^\d+$');

class Headers {
  Headers(this.protocolVersion, {int defaultPortForScheme = 80})
      : _headers = HashMap<String, List<String>>(),
        _defaultPortForScheme = defaultPortForScheme {
    if (protocolVersion == '1.0') {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  final String protocolVersion;

  final int _defaultPortForScheme;

  final Map<String, List<String>> _headers;

  List<String>? _noFoldingHeaders;

  int _contentLength = -1;

  bool _persistentConnection = true;

  bool _chunkedTransferEncoding = false;

  String? _host;

  int? _port;

  List<String>? operator [](String name) {
    return _headers[name];
  }

  String? value(String name) {
    var values = _headers[name];

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
    _add(name, value);
  }

  void set(String name, String value) {
    _headers.remove(name);

    if (name == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }

    if (name == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }

    _add(name, value);
  }

  void remove(String name, String value) {
    var values = _headers[name];

    if (values != null) {
      values.remove(value);

      if (values.isEmpty) {
        _headers.remove(name);
      }
    }

    if (name == HttpHeaders.transferEncodingHeader && value == 'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  void removeAll(String name) {
    _headers.remove(name);
  }

  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  void noFolding(String name) {
    var folding = _noFoldingHeaders ??= <String>[];
    folding.add(name);
  }

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
          throw HttpException("Trying to set 'Connection: Keep-Alive' on HTTP 1.0 headers with "
              'no ContentLength');
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
      throw HttpException('Trying to clear ContentLength on HTTP 1.0 headers with \'Connection: Keep-Alive\' set');
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
      _headers.remove(HttpHeaders.contentLengthHeader);

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
      var values = _headers[HttpHeaders.transferEncodingHeader];

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
    _host = host;
    _updateHostHeader();
  }

  int? get port {
    return _port;
  }

  set port(int? port) {
    _port = port;
    _updateHostHeader();
  }

  DateTime? get ifModifiedSince {
    var values = _headers[HttpHeaders.ifModifiedSinceHeader];

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
      _headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  DateTime? get date {
    var values = _headers[HttpHeaders.dateHeader];

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
      _headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(date.toUtc());
      _set(HttpHeaders.dateHeader, formatted);
    }
  }

  DateTime? get expires {
    var values = _headers[HttpHeaders.expiresHeader];

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
    if (expires == null) {
      _headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  ContentType? get contentType {
    var values = _headers[HttpHeaders.contentTypeHeader];

    if (values == null || values.isEmpty) {
      return null;
    }

    return ContentType.parse(values.first);
  }

  set contentType(ContentType? contentType) {
    if (contentType == null) {
      _headers.remove(HttpHeaders.contentTypeHeader);
    } else {
      _set(HttpHeaders.contentTypeHeader, contentType.toString());
    }
  }

  void clear() {
    _headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, String value) {
    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          _set(HttpHeaders.dateHeader, value);
          return;
        }

        if (HttpHeaders.hostHeader == name) {
          _addHost(name, value);
          return;
        }

        break;
      case 7:
        if (HttpHeaders.expiresHeader == name) {
          _set(HttpHeaders.expiresHeader, value);
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
          _set(HttpHeaders.contentTypeHeader, value);
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
          _set(HttpHeaders.ifModifiedSinceHeader, value);
          return;
        }
    }

    _addValue(name, value);
  }

  void _addContentLength(String name, String value) {
    if (!digitsValidator.hasMatch(value)) {
      throw HttpException('Content-Length must contain only digits');
    }

    contentLength = int.parse(value);
  }

  void _addTransferEncoding(String name, String value) {
    if (value == 'chunked') {
      chunkedTransferEncoding = true;
    } else {
      _addValue(HttpHeaders.transferEncodingHeader, value);
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

  void _addConnection(String name, String value) {
    var lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }

    _addValue(name, value);
  }

  void _addValue(String name, String value) {
    var values = _headers[name] ??= <String>[];
    values.add(value);
  }

  void _set(String name, String value) {
    _headers[name] = <String>[value];
  }

  void _updateHostHeader() {
    var host = _host;

    if (host != null) {
      var defaultPort = _port == null || _port == _defaultPortForScheme;
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

  void build(BytesBuilder builder, {bool skipZeroContentLength = false}) {
    // per https://tools.ietf.org/html/rfc7230#section-3.3.2
    // A user agent SHOULD NOT send a
    // Content-Length header field when the request message does not
    // contain a payload body and the method semantics do not anticipate
    // such a body.
    var ignoreHeader = _contentLength == 0 && skipZeroContentLength ? HttpHeaders.contentLengthHeader : null;

    void action(String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }

      var fold = foldHeader(name);
      var nameData = name.codeUnits;

      builder
        ..add(nameData)
        ..addByte(CharCodes.colon)
        ..addByte(CharCodes.sp);

      for (int i = 0; i < values.length; i++) {
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
    }

    _headers.forEach(action);
  }
}
