class Header {
  const Header(this.name, this.values);

  final String name;

  final List<String> values;

  @override
  String toString() {
    return 'Header($name: ${values.join(', ')})';
  }
}

class Headers {
  static const String accept = 'accept';
  static const String acceptEncoding = 'accept-encoding';
  static const String accessControlAllowCredentials = 'access-control-allow-credentials';
  static const String accessControlAllowHeaders = 'access-control-allow-headers';
  static const String accessControlAllowMethods = 'access-control-allow-methods';
  static const String accessControlAllowOrigin = 'access-control-allow-origin';
  static const String accessControlExposeHeaders = 'access-control-expose-headers';
  static const String accessControlMaxAge = 'access-control-max-age';
  static const String accessControlRequestHeaders = 'access-control-request-headers';
  static const String accessControlRequestMethod = 'access-control-request-method';
  static const String allow = 'allow';
  static const String authorization = 'authorization';
  static const String connection = 'connection';
  static const String contentDisposition = 'content-disposition';
  static const String contentEncoding = 'content-encoding';
  static const String contentLength = 'content-length';
  static const String contentSecurityPolicy = 'content-security-policy';
  static const String contentSecurityPolicyReportOnly = 'content-security-policy-report-only';
  static const String contentType = 'content-type';
  static const String cookie = 'cookie';
  static const String ifModifiedSince = 'if-modified-since';
  static const String lastModified = 'last-modified';
  static const String location = 'location';
  static const String origin = 'origin';
  static const String referrerPolicy = 'referrer-policy';
  static const String server = 'server';
  static const String setCookie = 'set-cookie';
  static const String strictTransportSecurity = 'strict-transport-security';
  static const String transferEncoding = 'transfer-encoding';
  static const String upgrade = 'upgrade';
  static const String vary = 'vary';
  static const String wwwAuthenticate = 'www-authenticate';
  static const String xContentTypeOptions = 'x-content-type-options';
  static const String xCSRFToken = 'x-csrf-token';
  static const String xForwardedFor = 'x-forwarded-for';
  static const String xForwardedProto = 'x-forwarded-proto';
  static const String xForwardedProtocol = 'x-forwarded-protocol';
  static const String xForwardedSsl = 'x-forwarded-ssl';
  static const String xFrameOptions = 'x-frame-options';
  static const String xHTTPMethodOverride = 'x-http-method-override';
  static const String xRealIP = 'x-real-ip';
  static const String xRequestedWith = 'x-requested-with';
  static const String xRequestID = 'x-request-id';
  static const String xURLScheme = 'x-url-scheme';
  static const String xXSSProtection = 'x-xss-protection';

  Headers({List<Header>? raw}) : raw = raw ?? <Header>[];

  final List<Header> raw;

  String? operator [](String name) {
    return get(name);
  }

  bool contains(String name) {
    name = name;

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (raw[index].name == name) {
        return true;
      }
    }

    return false;
  }

  String? get(String name) {
    for (var index = raw.length - 1; index >= 0; index -= 1) {
      name = name;

      if (raw[index].name == name) {
        var values = raw[index].values;
        return values.isEmpty ? null : values[0];
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    for (var header in raw) {
      if (name == header.name) {
        return header.values;
      }
    }

    return <String>[];
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw);
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({List<Header>? raw}) : super(raw: raw);

  void operator []=(String name, String value) {
    set(name, value);
  }

  void add(String name, String value) {
    raw.add(Header(name, <String>[value]));
  }

  void addAll(String name, List<String> values) {
    raw.add(Header(name, values));
  }

  void clear() {
    raw.clear();
  }

  void delete(String name, [String? value]) {
    for (var i = raw.length - 1; i >= 0; i -= 1) {
      if (raw[i].name == name) {
        if (value == null) {
          raw.removeAt(i);
        } else {
          raw[i].values.remove(value);
        }

        return;
      }
    }
  }

  void set(String name, String value) {
    for (var i = 0; i < raw.length; i += 1) {
      if (name == raw[i].name) {
        raw[i].values
          ..length = 1
          ..[0] = value;
        return;
      }
    }

    add(name, value);
  }

  void setAll(String name, List<String> values) {
    for (var i = 0; i < raw.length; i += 1) {
      if (name == raw[i].name) {
        raw[i] = Header(name, values);
        return;
      }
    }

    addAll(name, values);
  }

  @override
  MutableHeaders toMutable() {
    return this;
  }
}
