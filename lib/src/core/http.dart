// DataStreamMessage, HeadersStreamMessage, StreamMessage;

abstract class ContentTypes {
  static const String text = 'text/plain; charset=utf-8';

  static const String html = 'text/html; charset=utf-8';

  static const String json = 'application/json; charset=utf-8';
}

class Header {
  const Header(this.name, this.value);

  final String name;

  final String value;

  @override
  String toString() {
    return 'Header $name: $value';
  }
}

class Headers {
  static const String accept = 'accept';
  static const String acceptEncoding = 'accept-encoding';
  static const String accessControlAllowCredentials =
      'access-control-allow-credentials';
  static const String accessControlAllowHeaders =
      'access-control-allow-headers';
  static const String accessControlAllowMethods =
      'access-control-allow-methods';
  static const String accessControlAllowOrigin = 'access-control-allow-origin';
  static const String accessControlExposeHeaders =
      'access-control-expose-headers';
  static const String accessControlMaxAge = 'access-control-max-age';
  static const String accessControlRequestHeaders =
      'access-control-request-headers';
  static const String accessControlRequestMethod =
      'access-control-request-method';
  static const String allow = 'allow';
  static const String authorization = 'authorization';
  static const String contentDisposition = 'content-disposition';
  static const String contentEncoding = 'content-encoding';
  static const String contentLength = 'content-length';
  static const String contentSecurityPolicy = 'content-security-policy';
  static const String contentSecurityPolicyReportOnly =
      'content-security-policy-report-only';
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

  Headers({List<Header>? raw}) : raw = <Header>[] {
    if (raw != null) {
      raw.addAll(raw);
    }
  }

  final List<Header> raw;

  bool contains(String name) {
    name = name.toLowerCase();

    for (final pair in raw) {
      if (name == pair.name) {
        return true;
      }
    }

    return false;
  }

  String? get(String name) {
    name = name.toLowerCase();

    for (final header in raw.reversed) {
      if (name == header.name) {
        return header.value;
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    name = name.toLowerCase();

    return <String>[
      for (final header in raw)
        if (name == header.name) header.value
    ];
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw.toList());
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({List<Header>? raw}) : super(raw: raw);

  void add(String name, String value) {
    raw.add(Header(name, value));
  }

  void clear() {
    raw.clear();
  }

  void delete(String name) {
    final indexes = <int>[];

    name = name.toLowerCase();

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (name == raw[index].name) {
        indexes.add(index);
      }
    }

    for (final index in indexes) {
      raw.removeAt(index);
    }
  }

  void set(String name, String value) {
    final indexes = <int>[];

    name = name.toLowerCase();

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (name == raw[index].name) {
        indexes.add(index);
      }
    }

    if (indexes.isEmpty) {
      raw.add(Header(name, value));
    } else {
      final header = raw[indexes.removeLast()];
      raw[indexes.removeLast()] = Header(header.name, value);

      for (final index in indexes) {
        raw.removeAt(index);
      }
    }
  }
}

abstract class Message {
  const Message();
}

class DataMessage extends Message {
  static const DataMessage eos = DataMessage.empty(end: true);

  const DataMessage(this.bytes, {this.end = false});

  const DataMessage.empty({this.end = false}) : bytes = const <int>[];

  final List<int> bytes;

  final bool end;
}
