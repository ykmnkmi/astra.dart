import 'dart:io' show HttpHeaders, HttpStatus;

import 'package:http_parser/http_parser.dart' show parseHttpDate;

abstract class MediaTypes {
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
    return '$name: $value';
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
  static const String connection = 'connection';
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

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (raw[index].name == name) {
        return true;
      }
    }

    return false;
  }

  String? get(String name) {
    for (var index = raw.length - 1; index >= 0; index -= 1) {
      name = name.toLowerCase();

      if (raw[index].name == name) {
        return raw[index].value;
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    name = name.toLowerCase();
    return raw
        .where((header) => name == header.name)
        .map<String>((header) => header.value)
        .toList();
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw.toList());
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({List<Header>? raw}) : super(raw: raw);

  void operator []=(String name, String value) {
    set(name, value);
  }

  void add(String name, String value) {
    raw.add(Header(name.toLowerCase(), value));
  }

  void clear() {
    raw.clear();
  }

  void delete(String name) {
    var indexes = <int>[];
    name = name.toLowerCase();

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (raw[index].name == name) {
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
      if (raw[index].name == name) {
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

  @override
  MutableHeaders toMutable() {
    return this;
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

abstract class ReasonPhrases {
  static const String continue_ = 'Continue';
  static const String switchingProtocols = 'Switching Protocols';
  static const String ok = 'OK';
  static const String created = 'Created';
  static const String accepted = 'Accepted';
  static const String nonAuthoritativeInformation =
      'Non-Authoritative Information';
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
  static const String proxyAuthenticationRequired =
      'Proxy Authentication Required';
  static const String conflict = 'Conflict';
  static const String gone = 'Gone';
  static const String lengthRequired = 'Length Required';
  static const String preconditionFailed = 'Precondition Failed';
  static const String requestEntityTooLarge = 'Request Entity Too Large';
  static const String unsupportedMediaType = 'Unsupported Media Type';
  static const String requestedRangeNotSatisfiable =
      'Requested range not satisfiable';
  static const String expectationFailed = 'Expectation Failed';
  static const String upgradeRequired = 'Upgrade Required';
  static const String internalServerError = 'Internal Server Error';
  static const String notImplemented = 'Not Implemented';
  static const String badGateway = 'Bad Gateway';
  static const String serviceUnavailable = 'Service Unavailable';
  static const String httpVersionNotSupported = 'HTTP Version not supported';

  static String to(int status) {
    switch (status) {
      case HttpStatus.continue_:
        return continue_;
      case HttpStatus.switchingProtocols:
        return switchingProtocols;
      case HttpStatus.ok:
        return ok;
      case HttpStatus.created:
        return created;
      case HttpStatus.accepted:
        return accepted;
      case HttpStatus.nonAuthoritativeInformation:
        return nonAuthoritativeInformation;
      case HttpStatus.noContent:
        return noContent;
      case HttpStatus.resetContent:
        return resetContent;
      case HttpStatus.partialContent:
        return partialContent;
      case HttpStatus.multipleChoices:
        return multipleChoices;
      case HttpStatus.movedPermanently:
        return movedPermanently;
      case HttpStatus.found:
        return found;
      case HttpStatus.seeOther:
        return seeOther;
      case HttpStatus.notModified:
        return notModified;
      case HttpStatus.useProxy:
        return useProxy;
      case HttpStatus.temporaryRedirect:
        return temporaryRedirect;
      case HttpStatus.badRequest:
        return badRequest;
      case HttpStatus.unauthorized:
        return unauthorized;
      case HttpStatus.paymentRequired:
        return paymentRequired;
      case HttpStatus.forbidden:
        return forbidden;
      case HttpStatus.notFound:
        return notFound;
      case HttpStatus.methodNotAllowed:
        return methodNotAllowed;
      case HttpStatus.notAcceptable:
        return notAcceptable;
      case HttpStatus.proxyAuthenticationRequired:
        return proxyAuthenticationRequired;
      case HttpStatus.conflict:
        return conflict;
      case HttpStatus.gone:
        return gone;
      case HttpStatus.lengthRequired:
        return lengthRequired;
      case HttpStatus.preconditionFailed:
        return preconditionFailed;
      case HttpStatus.requestEntityTooLarge:
        return requestEntityTooLarge;
      case HttpStatus.unsupportedMediaType:
        return unsupportedMediaType;
      case HttpStatus.requestedRangeNotSatisfiable:
        return requestedRangeNotSatisfiable;
      case HttpStatus.expectationFailed:
        return expectationFailed;
      case HttpStatus.upgradeRequired:
        return upgradeRequired;
      case HttpStatus.internalServerError:
        return internalServerError;
      case HttpStatus.notImplemented:
        return notImplemented;
      case HttpStatus.badGateway:
        return badGateway;
      case HttpStatus.serviceUnavailable:
        return serviceUnavailable;
      case HttpStatus.httpVersionNotSupported:
        return httpVersionNotSupported;
      default:
        return '';
    }
  }
}

extension HeadersExtension on Headers {
  DateTime? get ifModifiedSince {
    var date = get(HttpHeaders.ifModifiedSinceHeader);

    if (date == null) {
      return null;
    } else {
      return parseHttpDate(date);
    }
  }
}
