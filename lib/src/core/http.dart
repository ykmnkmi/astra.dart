abstract class ContentTypes {
  static const String text = 'text/plain; charset=utf-8';

  static const String html = 'text/html; charset=utf-8';

  static const String json = 'application/json; charset=utf-8';

  static const String stream = 'application/octet-stream';
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

  Headers({List<Header>? raw}) : raw = <Header>[] {
    if (raw != null) {
      raw.addAll(raw);
    }
  }

  final List<Header> raw;

  @pragma('vm:prefer-inline')
  String? operator [](String name) {
    return get(name);
  }

  bool contains(String name) {
    name = name.toLowerCase();

    for (var pair in raw) {
      if (name == pair.name) {
        return true;
      }
    }

    return false;
  }

  String? get(String name) {
    name = name.toLowerCase();

    for (var header in raw.reversed) {
      if (name == header.name) {
        return header.value;
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    name = name.toLowerCase();

    return <String>[
      for (var header in raw)
        if (name == header.name) header.value
    ];
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw.toList());
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({List<Header>? raw}) : super(raw: raw);

  @pragma('vm:prefer-inline')
  void operator []=(String name, String value) {
    set(name, value);
  }

  void add(String name, String value) {
    raw.add(Header(name, value));
  }

  void clear() {
    raw.clear();
  }

  void delete(String name) {
    var indexes = <int>[];

    name = name.toLowerCase();

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (name == raw[index].name) {
        indexes.add(index);
      }
    }

    for (var index in indexes) {
      raw.removeAt(index);
    }
  }

  void set(String name, String value) {
    var indexes = <int>[];

    name = name.toLowerCase();

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (name == raw[index].name) {
        indexes.add(index);
      }
    }

    if (indexes.isEmpty) {
      raw.add(Header(name, value));
    } else {
      var index = indexes.removeLast();
      var header = raw[index];
      raw[index] = Header(header.name, value);

      for (var index in indexes) {
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

abstract class StatusCode {
  static const int kontinue = 100;
  static const int switchingProtocols = 101;
  static const int ok = 200;
  static const int created = 201;
  static const int accepted = 202;
  static const int nonAuthoritativeInformation = 203;
  static const int noContent = 204;
  static const int resetContent = 205;
  static const int partialContent = 206;
  static const int multipleChoices = 300;
  static const int movedPermanently = 301;
  static const int found = 302;
  static const int seeOther = 303;
  static const int notModified = 304;
  static const int useProxy = 305;
  static const int temporaryRedirect = 307;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int paymentRequired = 402;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int methodNotAllowed = 405;
  static const int notAcceptable = 406;
  static const int proxyAuthenticationRequired = 407;
  static const int requestTimeOut = 408;
  static const int conflict = 409;
  static const int gone = 410;
  static const int lengthRequired = 411;
  static const int preconditionFailed = 412;
  static const int requestEntityTooLarge = 413;
  static const int requestURITooLarge = 414;
  static const int unsupportedMediaType = 415;
  static const int requestedRangeNotSatisfiable = 416;
  static const int expectationFailed = 417;
  static const int internalServerError = 500;
  static const int notImplemented = 501;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeOut = 504;
  static const int httpVersionNotSupported = 505;
}

abstract class ReasonPhrase {
  static const String kontinue = 'Continue';
  static const String switchingProtocols = 'Switching Protocols';
  static const String ok = 'OK';
  static const String created = 'Created';
  static const String accepted = 'Accepted';
  static const String nonAuthoritativeInformation = 'Non-Authoritative Information';
  static const String noContent = 'No Content';
  static const String resetContent = 'Reset Content';
  static const String partialContent = 'Partial Content';
  static const String multipleChoices = 'Multiple Choices';
  static const String movedPermanently = 'Moved Permanently';
  static const String found = 'Found';
  static const String seeOther = 'See Other';
  static const String notModified = 'Not Modified';
  static const String useProxy = 'Use Proxy';
  static const String temporaryRedirect = 'Temporary Redirect';
  static const String badRequest = 'Bad Request';
  static const String unauthorized = 'Unauthorized';
  static const String paymentRequired = 'Payment Required';
  static const String forbidden = 'Forbidden';
  static const String notFound = 'Not Found';
  static const String methodNotAllowed = 'Method Not Allowed';
  static const String notAcceptable = 'Not Acceptable';
  static const String proxyAuthenticationRequired = 'Proxy Authentication Required';
  static const String requestTimeOut = 'Request Time-out';
  static const String conflict = 'Conflict';
  static const String gone = 'Gone';
  static const String lengthRequired = 'Length Required';
  static const String preconditionFailed = 'Precondition Failed';
  static const String requestEntityTooLarge = 'Request Entity Too Large';
  static const String requestURITooLarge = 'Request-URI Too Large';
  static const String unsupportedMediaType = 'Unsupported Media Type';
  static const String requestedRangeNotSatisfiable = 'Requested range not satisfiable';
  static const String expectationFailed = 'Expectation Failed';
  static const String internalServerError = 'Internal Server Error';
  static const String notImplemented = 'Not Implemented';
  static const String badGateway = 'Bad Gateway';
  static const String serviceUnavailable = 'Service Unavailable';
  static const String gatewayTimeOut = 'Gateway Time-out';
  static const String httpVersionNotSupported = 'HTTP Version not supported';

  static String from(int status) {
    switch (status) {
      case StatusCode.kontinue:
        return kontinue;
      case StatusCode.switchingProtocols:
        return switchingProtocols;
      case StatusCode.ok:
        return ok;
      case StatusCode.created:
        return created;
      case StatusCode.accepted:
        return accepted;
      case StatusCode.nonAuthoritativeInformation:
        return nonAuthoritativeInformation;
      case StatusCode.noContent:
        return noContent;
      case StatusCode.resetContent:
        return resetContent;
      case StatusCode.partialContent:
        return partialContent;
      case StatusCode.multipleChoices:
        return multipleChoices;
      case StatusCode.movedPermanently:
        return movedPermanently;
      case StatusCode.found:
        return found;
      case StatusCode.seeOther:
        return seeOther;
      case StatusCode.notModified:
        return notModified;
      case StatusCode.useProxy:
        return useProxy;
      case StatusCode.temporaryRedirect:
        return temporaryRedirect;
      case StatusCode.badRequest:
        return badRequest;
      case StatusCode.unauthorized:
        return unauthorized;
      case StatusCode.paymentRequired:
        return paymentRequired;
      case StatusCode.forbidden:
        return forbidden;
      case StatusCode.notFound:
        return notFound;
      case StatusCode.methodNotAllowed:
        return methodNotAllowed;
      case StatusCode.notAcceptable:
        return notAcceptable;
      case StatusCode.proxyAuthenticationRequired:
        return proxyAuthenticationRequired;
      case StatusCode.requestTimeOut:
        return requestTimeOut;
      case StatusCode.conflict:
        return conflict;
      case StatusCode.gone:
        return gone;
      case StatusCode.lengthRequired:
        return lengthRequired;
      case StatusCode.preconditionFailed:
        return preconditionFailed;
      case StatusCode.requestEntityTooLarge:
        return requestEntityTooLarge;
      case StatusCode.requestURITooLarge:
        return requestURITooLarge;
      case StatusCode.unsupportedMediaType:
        return unsupportedMediaType;
      case StatusCode.requestedRangeNotSatisfiable:
        return requestedRangeNotSatisfiable;
      case StatusCode.expectationFailed:
        return expectationFailed;
      case StatusCode.internalServerError:
        return internalServerError;
      case StatusCode.notImplemented:
        return notImplemented;
      case StatusCode.badGateway:
        return badGateway;
      case StatusCode.serviceUnavailable:
        return serviceUnavailable;
      case StatusCode.gatewayTimeOut:
        return gatewayTimeOut;
      case StatusCode.httpVersionNotSupported:
        return httpVersionNotSupported;
      default:
        return '';
    }
  }
}
