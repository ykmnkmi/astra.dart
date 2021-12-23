import 'dart:io' show IOSink;

import 'package:meta/meta.dart';

import 'http.dart';
import 'types.dart';

class Request {
  Request(this.stream, this.sink, this.method, this.uri, this.version,
      this.headers, this.start, this.send, this.flusher, this.closer);

  final Stream<List<int>> stream;

  final IOSink sink;

  String method;

  Uri uri;

  String version;

  Headers headers;

  Start start;

  Send send;

  @protected
  Future<void> Function() flusher;

  @protected
  Future<void> Function() closer;

  Future<void> flush() {
    return flusher();
  }

  Future<void> close() {
    return closer();
  }
}
