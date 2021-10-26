import 'dart:convert' show json, utf8;
import 'dart:io' show File, FileSystemEntityType, HttpStatus;

import 'package:http_parser/http_parser.dart' show formatHttpDate;
import 'package:mime/mime.dart' show MimeTypeResolver;
import 'package:path/path.dart' as path show normalize;

import 'http.dart';
import 'request.dart';

class Response<T extends Object?> {
  Response.ok({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.ok, mediaType: contentType, headers: headers, content: content);

  Response.created({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.created, mediaType: contentType, headers: headers, content: content);

  Response.accepted({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.accepted, mediaType: contentType, headers: headers, content: content);

  Response.noContent({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.noContent, mediaType: contentType, headers: headers, content: content);

  Response.notModified({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.notModified, mediaType: contentType, headers: headers, content: content);

  Response.badRequest({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.badRequest, mediaType: contentType, headers: headers, content: content);

  Response.unauthorized({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.unauthorized, mediaType: contentType, headers: headers, content: content);

  Response.forbidden({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.forbidden, mediaType: contentType, headers: headers, content: content);

  Response.notFound({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.notFound, mediaType: contentType, headers: headers, content: content);

  Response.conflict({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.conflict, mediaType: contentType, headers: headers, content: content);

  Response.gone({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.gone, mediaType: contentType, headers: headers, content: content);

  Response.error({String? contentType, Map<String, String>? headers, T? content})
      : this(status: HttpStatus.internalServerError, mediaType: contentType, headers: headers, content: content);

  Response({this.status = HttpStatus.ok, this.mediaType, Map<String, String>? headers, T? content})
      : headers = MutableHeaders() {
    body = render(content);

    var populateContentLength = true;
    var populateContentType = true;

    if (headers != null) {
      var keys = <String>{};

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

    if (mediaType != null && populateContentType) {
      this.headers.add(Headers.contentType, mediaType!);
    }
  }

  late final List<int> body;

  final int status;

  final MutableHeaders headers;

  String? mediaType;

  Future<void> call(Request request) async {
    request
      ..start(status, headers: headers.raw)
      ..send(body);
    await request.flush();
    return request.close();
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
  TextResponse.html(String? content,
      {int status = HttpStatus.ok, String contentType = MediaTypes.html, Map<String, String>? headers})
      : this(content, status: status, contentType: contentType, headers: headers);

  TextResponse(String? content,
      {int status = HttpStatus.ok, String contentType = MediaTypes.text, Map<String, String>? headers})
      : super(status: status, mediaType: contentType, headers: headers, content: content);

  @override
  List<int> render(String? content) {
    if (content == null) {
      return const <int>[];
    }

    return utf8.encode(content);
  }
}

class JSONResponse extends Response {
  JSONResponse(Object? content, {int status = HttpStatus.ok, Map<String, String>? headers})
      : super(status: status, mediaType: MediaTypes.json, headers: headers, content: content);

  @override
  List<int> render(Object? content) {
    return utf8.encode(json.encode(content));
  }
}

class RedirectResponse extends Response {
  RedirectResponse(Uri url, {int status = HttpStatus.temporaryRedirect, Map<String, String>? headers})
      : super(status: status, headers: headers) {
    this.headers[Headers.location] = '$url';
  }
}

class StreamResponse extends Response {
  StreamResponse.text(Stream<String> stream,
      {bool buffer = true, int status = HttpStatus.ok, Map<String, String>? headers})
      : this(utf8.encoder.bind(stream), buffer: buffer, status: status, mediaType: MediaTypes.text, headers: headers);

  StreamResponse.html(Stream<String> stream,
      {bool buffer = true, int status = HttpStatus.ok, Map<String, String>? headers})
      : this(utf8.encoder.bind(stream), buffer: buffer, status: status, mediaType: MediaTypes.html, headers: headers);

  StreamResponse.json(Stream<String> stream,
      {bool buffer = true, int status = HttpStatus.ok, Map<String, String>? headers})
      : this(utf8.encoder.bind(stream), buffer: buffer, status: status, mediaType: MediaTypes.json, headers: headers);

  StreamResponse(this.stream,
      {this.buffer = true,
      int status = HttpStatus.ok,
      String mediaType = MediaTypes.stream,
      Map<String, String>? headers})
      : super(status: status, mediaType: mediaType, headers: headers);

  final Stream<List<int>> stream;

  final bool buffer;

  @override
  Future<void> call(Request request) async {
    request.start(status, headers: headers.raw, buffer: buffer);

    await for (var bytes in stream) {
      request.send(bytes);
    }

    await request.flush();
    return request.close();
  }
}

class FileResponse extends Response {
  FileResponse(String filePath,
      {String? fileName, String? method, int status = HttpStatus.ok, String? contentType, Map<String, String>? headers})
      : this.file(File(path.normalize(filePath)),
            fileName: fileName, method: method, status: status, contentType: contentType, headers: headers);

  FileResponse.file(this.file,
      {String? fileName, String? method, int status = HttpStatus.ok, String? contentType, Map<String, String>? headers})
      : sendHeaderOnly = method != null && method.toUpperCase() == 'HEAD',
        super(status: status, mediaType: contentType ?? guessType(fileName ?? file.path), headers: headers) {
    if (fileName != null) {
      var contentDispositionFileName = Uri.encodeFull(fileName);
      this.headers[Headers.contentDisposition] = contentDispositionFileName == fileName
          ? 'attachment; filename="$contentDispositionFileName"'
          : 'attachment; filename*=utf-8\'\'$contentDispositionFileName';
    }
  }

  final File file;

  final bool sendHeaderOnly;

  @override
  Future<void> call(Request request) async {
    var stat = await file.stat();

    if (stat.type == FileSystemEntityType.notFound) {
      throw StateError('file at path ${file.path} does not exist');
    }

    if (stat.type != FileSystemEntityType.file) {
      throw StateError('file at path ${file.path} is not a file');
    }

    var ifModifiedSince = request.headers.ifModifiedSince;

    if (ifModifiedSince != null) {
      if (ifModifiedSince.isAfter(stat.modified)) {
        request.start(HttpStatus.notModified, headers: headers.raw);
        return request.close();
      }
    }

    headers
      ..[Headers.contentLength] = '${stat.size}'
      ..[Headers.lastModified] = formatHttpDate(stat.modified);

    request.start(status, headers: headers.raw);

    if (sendHeaderOnly) {
      return request.close();
    } else {
      await for (var bytes in file.openRead()) {
        request.send(bytes);
      }

      await request.flush();
      return request.close();
    }
  }

  static MimeTypeResolver? mimeTypeResolver;

  static String? guessType(String filePath) {
    var resolver = mimeTypeResolver ??= MimeTypeResolver();
    return resolver.lookup(filePath) ?? MediaTypes.text;
  }
}
