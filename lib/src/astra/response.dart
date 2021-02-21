part of '../../astra.dart';

Future<Message> emptyStart(int statusCode, List<Header> headers) {
  throw UnimplementedError();
}

Future<Message> emptyRespond(List<int> body) {
  throw UnimplementedError();
}

abstract class Response<T extends Object> {
  Response({this.statusCode = HttpStatus.ok, this.contentType = ContentTypes.text, Map<String, String>? headers, T? content}) : rawHeaders = <Header>[] {
    body = render(content);

    var populateContentLength = true;
    var populateContentType = true;

    if (headers != null) {
      final keys = <String>{};

      for (final entry in headers.entries) {
        keys.add(entry.key);
        rawHeaders.add(Header(ascii.encode(entry.key.toLowerCase()), ascii.encode(entry.value)));
        populateContentLength = !keys.contains('content-length');
        populateContentType = !keys.contains('content-type');
      }
    }

    if (body.isNotEmpty && populateContentLength) {
      rawHeaders.add(Header(ascii.encode('content-length'), ascii.encode(body.length.toString())));
    }

    if (populateContentType) {
      rawHeaders.add(Header(ascii.encode('content-type'), ascii.encode(contentType)));
    }
  }

  int statusCode;

  String contentType;

  List<Header> rawHeaders;

  late List<int> body;

  MutableHeaders get headers => MutableHeaders(raw: rawHeaders);

  Future<void> call(Start start, Respond respond) async {
    await start(statusCode, rawHeaders);
    await respond(body);
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

    throw Exception('wrong type: ${content.runtimeType}');
  }
}

class TextResponse extends Response<String> {
  TextResponse(String? content, {int status = HttpStatus.ok, Map<String, String>? headers}) : super(statusCode: status, headers: headers, content: content);
}

class HTMLResponse extends Response<String> {
  HTMLResponse(String? content, {int status = HttpStatus.ok, Map<String, String>? headers})
      : super(statusCode: status, contentType: ContentTypes.html, headers: headers, content: content);
}

class JSONResponse extends Response<Object> {
  JSONResponse(Object? content, {int status = HttpStatus.ok, Map<String, String>? headers})
      : super(statusCode: status, contentType: ContentTypes.json, headers: headers, content: content);

  @override
  List<int> render(Object? content) {
    return super.render(json.encode(content));
  }
}
