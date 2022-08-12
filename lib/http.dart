library astra.http;

import 'dart:async';
import 'dart:collection' show HashMap, LinkedList, LinkedListEntry;
import 'dart:convert';
import 'dart:io'
    show
        ContentType,
        HandshakeException,
        HttpDate,
        HttpException,
        HttpStatus,
        IOSink,
        InternetAddress,
        InternetAddressType,
        RawSocketOption,
        SecureSocket,
        ServerSocket,
        Socket,
        SocketException,
        SocketOption,
        TlsException,
        X509Certificate,
        ZLibEncoder;
import 'dart:typed_data';

part 'src/http/headers.dart';
part 'src/http/core.dart';
part 'src/http/parser.dart';

abstract class AstraServer implements Stream<AstraRequest> {
  factory AstraServer.listenOn(ServerSocket serverSocket) {
    return NativeServer.listenOn(serverSocket);
  }

  String? serverHeader;

  AstraHeaders get defaultResponseHeaders;

  bool autoCompress = false;

  Duration? idleTimeout = const Duration(seconds: 120);

  int get port;

  InternetAddress get address;

  Future<void> close({bool force = false});

  static Future<AstraServer> bind(Object address, int port, //
      {int backlog = 0,
      bool v6Only = false,
      bool shared = false}) {
    return NativeServer.bind(address, port, backlog, v6Only, shared);
  }
}

abstract class AstraHeaders {
  static const String acceptHeader = 'accept';
  static const String acceptCharsetHeader = 'accept-charset';
  static const String acceptEncodingHeader = 'accept-encoding';
  static const String acceptLanguageHeader = 'accept-language';
  static const String acceptRangesHeader = 'accept-ranges';
  static const String accessControlAllowCredentialsHeader = 'access-control-allow-credentials';
  static const String accessControlAllowHeadersHeader = 'access-control-allow-headers';
  static const String accessControlAllowMethodsHeader = 'access-control-allow-methods';
  static const String accessControlAllowOriginHeader = 'access-control-allow-origin';
  static const String accessControlExposeHeadersHeader = 'access-control-expose-headers';
  static const String accessControlMaxAgeHeader = 'access-control-max-age';
  static const String accessControlRequestHeadersHeader = 'access-control-request-headers';
  static const String accessControlRequestMethodHeader = 'access-control-request-method';
  static const String ageHeader = 'age';
  static const String allowHeader = 'allow';
  static const String authorizationHeader = 'authorization';
  static const String cacheControlHeader = 'cache-control';
  static const String connectionHeader = 'connection';
  static const String contentEncodingHeader = 'content-encoding';
  static const String contentLanguageHeader = 'content-language';
  static const String contentLengthHeader = 'content-length';
  static const String contentLocationHeader = 'content-location';
  static const String contentMD5Header = 'content-md5';
  static const String contentRangeHeader = 'content-range';
  static const String contentTypeHeader = 'content-type';
  static const String dateHeader = 'date';
  static const String etagHeader = 'etag';
  static const String expectHeader = 'expect';
  static const String expiresHeader = 'expires';
  static const String fromHeader = 'from';
  static const String hostHeader = 'host';
  static const String ifMatchHeader = 'if-match';
  static const String ifModifiedSinceHeader = 'if-modified-since';
  static const String ifNoneMatchHeader = 'if-none-match';
  static const String ifRangeHeader = 'if-range';
  static const String ifUnmodifiedSinceHeader = 'if-unmodified-since';
  static const String lastModifiedHeader = 'last-modified';
  static const String locationHeader = 'location';
  static const String maxForwardsHeader = 'max-forwards';
  static const String pragmaHeader = 'pragma';
  static const String proxyAuthenticateHeader = 'proxy-authenticate';
  static const String proxyAuthorizationHeader = 'proxy-authorization';
  static const String rangeHeader = 'range';
  static const String refererHeader = 'referer';
  static const String retryAfterHeader = 'retry-after';
  static const String serverHeader = 'server';
  static const String teHeader = 'te';
  static const String trailerHeader = 'trailer';
  static const String transferEncodingHeader = 'transfer-encoding';
  static const String upgradeHeader = 'upgrade';
  static const String userAgentHeader = 'user-agent';
  static const String varyHeader = 'vary';
  static const String viaHeader = 'via';
  static const String warningHeader = 'warning';
  static const String wwwAuthenticateHeader = 'www-authenticate';

  // Cookie headers from RFC 6265.
  static const String cookieHeader = 'cookie';
  static const String setCookieHeader = 'set-cookie';

  static const List<String> generalHeaders = <String>[
    cacheControlHeader,
    connectionHeader,
    dateHeader,
    pragmaHeader,
    trailerHeader,
    transferEncodingHeader,
    upgradeHeader,
    viaHeader,
    warningHeader
  ];

  static const List<String> entityHeaders = <String>[
    allowHeader,
    contentEncodingHeader,
    contentLanguageHeader,
    contentLengthHeader,
    contentLocationHeader,
    contentMD5Header,
    contentRangeHeader,
    contentTypeHeader,
    expiresHeader,
    lastModifiedHeader
  ];

  static const List<String> responseHeaders = <String>[
    acceptRangesHeader,
    ageHeader,
    etagHeader,
    locationHeader,
    proxyAuthenticateHeader,
    retryAfterHeader,
    serverHeader,
    varyHeader,
    wwwAuthenticateHeader
  ];

  static const List<String> requestHeaders = <String>[
    acceptHeader,
    acceptCharsetHeader,
    acceptEncodingHeader,
    acceptLanguageHeader,
    authorizationHeader,
    expectHeader,
    fromHeader,
    hostHeader,
    ifMatchHeader,
    ifModifiedSinceHeader,
    ifNoneMatchHeader,
    ifRangeHeader,
    ifUnmodifiedSinceHeader,
    maxForwardsHeader,
    proxyAuthorizationHeader,
    rangeHeader,
    refererHeader,
    teHeader,
    userAgentHeader
  ];

  DateTime? date;

  DateTime? expires;

  DateTime? ifModifiedSince;

  String? host;

  int? port;

  ContentType? contentType;

  int contentLength = -1;

  late bool persistentConnection;

  late bool chunkedTransferEncoding;

  List<String>? operator [](String name);

  String? value(String name);

  void add(String name, Object value, {bool preserveHeaderCase = false});

  void set(String name, Object value, {bool preserveHeaderCase = false});

  void remove(String name, Object value);

  void removeAll(String name);

  void forEach(void Function(String name, List<String> values) action);

  void noFolding(String name);

  void clear();
}

abstract class AstraRequest implements Stream<Uint8List> {
  int get contentLength;

  String get method;

  Uri get uri;

  Uri get requestedUri;

  AstraHeaders get headers;

  bool get persistentConnection;

  X509Certificate? get certificate;

  String get protocolVersion;

  AstraResponse get response;
}

abstract class AstraResponse implements IOSink {
  int contentLength = -1;

  int statusCode = HttpStatus.ok;

  late String reasonPhrase;

  late bool persistentConnection;

  Duration? deadline;

  bool bufferOutput = true;

  AstraHeaders get headers;

  Future<void> redirect(Uri location, {int status = HttpStatus.movedTemporarily});

  Future<Socket> detachSocket({bool writeHeaders = true});
}
