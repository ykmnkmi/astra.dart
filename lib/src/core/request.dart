import 'dart:io' show IOSink;

import 'http.dart';
import 'types.dart';

abstract class Request {
  String get version;

  String get method;

  Uri get url;

  Headers get headers;

  Stream<List<int>> get stream;

  abstract Start start;

  abstract Send send;

  abstract Future<void> Function() flush;

  abstract Future<void> Function() close;

  @override
  String toString() {
    return 'Request($method, $url, $version)';
  }
}

class RequestImpl extends Request {
  RequestImpl(this.stream, this.sink, this.method, this.url, this.version, this.headers, this.start, this.send,
      this.flush, this.close);

  @override
  final Stream<List<int>> stream;

  final IOSink sink;

  @override
  String method;

  @override
  Uri url;

  @override
  String version;

  @override
  Headers headers;

  @override
  Start start;

  @override
  Send send;

  @override
  Future<void> Function() flush;

  @override
  Future<void> Function() close;
}
