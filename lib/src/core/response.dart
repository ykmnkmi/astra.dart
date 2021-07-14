import 'dart:async' show FutureOr;
import 'dart:convert' show json, utf8;
import 'dart:io' show File, FileSystemEntityType;

import 'package:astra/astra.dart';
import 'package:http_parser/http_parser.dart' show formatHttpDate;
import 'package:mime/mime.dart' show MimeTypeResolver;
import 'package:path/path.dart' as path show normalize;

import 'http.dart';
import 'request.dart';
import 'types.dart';

class Response<T extends Object?> {
  Response.ok({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.ok, contentType: contentType, headers: headers, content: content);

  Response.created({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.created, contentType: contentType, headers: headers, content: content);

  Response.accepted({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.accepted, contentType: contentType, headers: headers, content: content);

  Response.noContent({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.noContent, contentType: contentType, headers: headers, content: content);

  Response.notModified({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.notModified, contentType: contentType, headers: headers, content: content);

  Response.badRequest({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.badRequest, contentType: contentType, headers: headers, content: content);

  Response.unauthorized({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.unauthorized, contentType: contentType, headers: headers, content: content);

  Response.forbidden({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.forbidden, contentType: contentType, headers: headers, content: content);

  Response.notFound({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.notFound, contentType: contentType, headers: headers, content: content);

  Response.conflict({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.conflict, contentType: contentType, headers: headers, content: content);

  Response.gone({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.gone, contentType: contentType, headers: headers, content: content);

  Response.error({String? contentType, Map<String, String>? headers, T? content})
      : this(status: StatusCodes.internalServerError, contentType: contentType, headers: headers, content: content);

  Response({this.status = StatusCodes.ok, this.contentType, Map<String, String>? headers, T? content})
      : headers = MutableHeaders() {
    body = render(content);

    var populateContentLength = true;
    var populateContentType = true;

    if (headers != null) {
      final keys = <String>{};

      for (var key in headers.keys) {
        key = key.toLowerCase();
        keys.add(key);
        this.headers.add(key, headers[key]!);
      }

      populateContentLength = !keys.contains(Headers.contentLength);
      populateContentType = !keys.contains(Headers.contentType);
    }

    if (body.isNotEmpty && populateContentLength) {
      this.headers.add(Headers.contentLength, '${body.length}');
    }

    if (contentType != null && populateContentType) {
      this.headers.add(Headers.contentType, contentType!);
    }
  }

  late final List<int> body;

  int status;

  MutableHeaders headers;

  String? contentType;

  FutureOr<void> call(Request request, Start start, Send send) {
    start(status: status, headers: headers.raw);
    return send(bytes: body, end: true);
  }

  List<int> render(T? content) {
    if (content == null) {
      return const <int>[];
    }

    if (content is List<int>) {
      return content;
    }

    if (content is String) {
      return utf8.encode(content);
    }

    if (content is Iterable<int>) {
      return content.toList();
    }

    throw TypeError();
  }
}

class TextResponse extends Response<String> {
  factory TextResponse.html(String? content,
      {int status = StatusCodes.ok, String contentType = ContentTypes.html, Map<String, String>? headers}) {
    return TextResponse(content, status: status, contentType: contentType, headers: headers);
  }

  TextResponse(String? content,
      {int status = StatusCodes.ok, String contentType = ContentTypes.text, Map<String, String>? headers})
      : super(status: status, contentType: contentType, headers: headers, content: content);

  @override
  List<int> render(String? content) {
    if (content == null) {
      return const <int>[];
    }

    return utf8.encode(content);
  }
}

class JSONResponse extends Response {
  JSONResponse(Object? content, {int status = StatusCodes.ok, Map<String, String>? headers})
      : super(status: status, contentType: ContentTypes.json, headers: headers, content: content);

  @override
  List<int> render(Object? content) {
    return utf8.encode(json.encode(content));
  }
}

class RedirectResponse extends Response {
  RedirectResponse(Uri url, {int status = StatusCodes.temporaryRedirect, Map<String, String>? headers})
      : super(status: status, headers: headers) {
    this.headers[Headers.location] = '$url';
  }
}

class StreamResponse extends Response {
  StreamResponse.text(Stream<String> stream,
      {bool buffer = true, int status = StatusCodes.ok, Map<String, String>? headers})
      : this(utf8.encoder.bind(stream),
            buffer: buffer, status: status, contentType: ContentTypes.text, headers: headers);

  StreamResponse.html(Stream<String> stream,
      {bool buffer = true, int status = StatusCodes.ok, Map<String, String>? headers})
      : this(utf8.encoder.bind(stream),
            buffer: buffer, status: status, contentType: ContentTypes.html, headers: headers);

  StreamResponse.json(Stream<String> stream,
      {bool buffer = true, int status = StatusCodes.ok, Map<String, String>? headers})
      : this(utf8.encoder.bind(stream),
            buffer: buffer, status: status, contentType: ContentTypes.json, headers: headers);

  StreamResponse(this.stream,
      {this.buffer = true,
      int status = StatusCodes.ok,
      String contentType = ContentTypes.stream,
      Map<String, String>? headers})
      : super(status: status, contentType: contentType, headers: headers);

  final Stream<List<int>> stream;

  final bool buffer;

  @override
  Future<void> call(Request request, Start start, Send send) async {
    start(status: status, headers: headers.raw);

    await for (var bytes in stream) {
      send(bytes: bytes);
    }

    return send(end: true);
  }
}

class FileResponse extends Response {
  FileResponse(String filePath,
      {String? fileName,
      String? method,
      int status = StatusCodes.ok,
      String? contentType,
      Map<String, String>? headers})
      : this.file(File(path.normalize(filePath)),
            fileName: fileName, method: method, status: status, contentType: contentType, headers: headers);

  FileResponse.file(this.file,
      {String? fileName,
      String? method,
      int status = StatusCodes.ok,
      String? contentType,
      Map<String, String>? headers})
      : sendHeaderOnly = method != null && method.toUpperCase() == 'HEAD',
        super(status: status, contentType: contentType ?? guessType(fileName ?? file.path), headers: headers) {
    if (fileName != null) {
      var contentDispositionFileName = Uri.encodeFull(fileName);
      this.headers[Headers.contentDisposition] = contentDispositionFileName == fileName
          ? 'attachment; filename="$contentDispositionFileName"'
          : 'attachment; filename*=utf-8\'\'$contentDispositionFileName';
    }
  }

  File file;

  bool sendHeaderOnly;

  @override
  Future<void> call(Request request, Start start, Send send) async {
    var fileStat = await file.stat();

    if (fileStat.type == FileSystemEntityType.notFound) {
      throw StateError('file at path ${file.path} does not exist');
    }

    if (fileStat.type != FileSystemEntityType.file) {
      throw StateError('file at path ${file.path} is not a file');
    }

    var ifModifiedSince = request.ifModifiedSince;

    if (ifModifiedSince != null) {
      if (!fileStat.modified.isAfter(ifModifiedSince)) {
        start(status: StatusCodes.notModified, headers: headers.raw);
        return send(end: true);
      }
    }

    headers
      ..[Headers.contentLength] = '${fileStat.size}'
      ..[Headers.lastModified] = formatHttpDate(fileStat.modified);

    start(status: status, headers: headers.raw);

    if (sendHeaderOnly) {
      return send(end: true);
    }

    await for (var bytes in file.openRead()) {
      send(bytes: bytes);
    }

    return send(end: true);
  }

  static MimeTypeResolver? mimeTypeResolver;

  static String? guessType(String filePath) {
    var resolver = mimeTypeResolver ??= MimeTypeResolver();
    return resolver.lookup(filePath) ?? ContentTypes.text;
  }
}
