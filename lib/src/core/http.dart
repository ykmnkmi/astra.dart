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

abstract class StatusCodes {
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
  static const int upgradeRequired = 426;
  static const int internalServerError = 500;
  static const int notImplemented = 501;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeOut = 504;
  static const int httpVersionNotSupported = 505;
}

abstract class ReasonPhrases {
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
  static const String upgradeRequired = 'Upgrade Required';
  static const String internalServerError = 'Internal Server Error';
  static const String notImplemented = 'Not Implemented';
  static const String badGateway = 'Bad Gateway';
  static const String serviceUnavailable = 'Service Unavailable';
  static const String gatewayTimeOut = 'Gateway Time-out';
  static const String httpVersionNotSupported = 'HTTP Version not supported';

  static String from(int status) {
    switch (status) {
      case StatusCodes.kontinue:
        return kontinue;
      case StatusCodes.switchingProtocols:
        return switchingProtocols;
      case StatusCodes.ok:
        return ok;
      case StatusCodes.created:
        return created;
      case StatusCodes.accepted:
        return accepted;
      case StatusCodes.nonAuthoritativeInformation:
        return nonAuthoritativeInformation;
      case StatusCodes.noContent:
        return noContent;
      case StatusCodes.resetContent:
        return resetContent;
      case StatusCodes.partialContent:
        return partialContent;
      case StatusCodes.multipleChoices:
        return multipleChoices;
      case StatusCodes.movedPermanently:
        return movedPermanently;
      case StatusCodes.found:
        return found;
      case StatusCodes.seeOther:
        return seeOther;
      case StatusCodes.notModified:
        return notModified;
      case StatusCodes.useProxy:
        return useProxy;
      case StatusCodes.temporaryRedirect:
        return temporaryRedirect;
      case StatusCodes.badRequest:
        return badRequest;
      case StatusCodes.unauthorized:
        return unauthorized;
      case StatusCodes.paymentRequired:
        return paymentRequired;
      case StatusCodes.forbidden:
        return forbidden;
      case StatusCodes.notFound:
        return notFound;
      case StatusCodes.methodNotAllowed:
        return methodNotAllowed;
      case StatusCodes.notAcceptable:
        return notAcceptable;
      case StatusCodes.proxyAuthenticationRequired:
        return proxyAuthenticationRequired;
      case StatusCodes.requestTimeOut:
        return requestTimeOut;
      case StatusCodes.conflict:
        return conflict;
      case StatusCodes.gone:
        return gone;
      case StatusCodes.lengthRequired:
        return lengthRequired;
      case StatusCodes.preconditionFailed:
        return preconditionFailed;
      case StatusCodes.requestEntityTooLarge:
        return requestEntityTooLarge;
      case StatusCodes.requestURITooLarge:
        return requestURITooLarge;
      case StatusCodes.unsupportedMediaType:
        return unsupportedMediaType;
      case StatusCodes.requestedRangeNotSatisfiable:
        return requestedRangeNotSatisfiable;
      case StatusCodes.expectationFailed:
        return expectationFailed;
      case StatusCodes.upgradeRequired:
        return upgradeRequired;
      case StatusCodes.internalServerError:
        return internalServerError;
      case StatusCodes.notImplemented:
        return notImplemented;
      case StatusCodes.badGateway:
        return badGateway;
      case StatusCodes.serviceUnavailable:
        return serviceUnavailable;
      case StatusCodes.gatewayTimeOut:
        return gatewayTimeOut;
      case StatusCodes.httpVersionNotSupported:
        return httpVersionNotSupported;
      default:
        return '';
    }
  }
}
