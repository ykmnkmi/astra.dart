import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';

class AstraRequest implements Request {
  @override
  bool get canHijack => throw UnimplementedError();

  @override
  int? get contentLength => throw UnimplementedError();

  @override
  Map<String, Object> get context => throw UnimplementedError();

  @override
  Encoding? get encoding => throw UnimplementedError();

  @override
  String get handlerPath => throw UnimplementedError();

  @override
  Map<String, String> get headers => throw UnimplementedError();

  @override
  Map<String, List<String>> get headersAll => throw UnimplementedError();

  @override
  DateTime? get ifModifiedSince => throw UnimplementedError();

  @override
  bool get isEmpty => throw UnimplementedError();

  @override
  String get method => throw UnimplementedError();

  @override
  String? get mimeType => throw UnimplementedError();

  @override
  String get protocolVersion => throw UnimplementedError();

  @override
  Uri get requestedUri => throw UnimplementedError();

  @override
  Uri get url => throw UnimplementedError();

  @override
  Request change(
      {Map<String, Object?>? headers, Map<String, Object?>? context, String? path, Object? body}) {
    throw UnimplementedError();
  }

  @override
  Never hijack(void Function(StreamChannel<List<int>> p1) callback) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> read() {
    throw UnimplementedError();
  }

  @override
  Future<String> readAsString([Encoding? encoding]) {
    throw UnimplementedError();
  }
}
