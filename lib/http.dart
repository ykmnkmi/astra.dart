import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'astra.dart';

FutureOr<void> Function(HttpRequest request) serve(Handler handler) {
  return (request) {
    handler(AstraHttpRequest(request));
  };
}

class AstraHttpHeaders implements Headers {
  static Expando<AstraHttpHeaders> store = Expando<AstraHttpHeaders>();

  factory AstraHttpHeaders(HttpRequest request) {
    return store[request] ??= AstraHttpHeaders.from(request.headers);
  }

  AstraHttpHeaders.from(this.headers);

  final HttpHeaders headers;

  @override
  List<Header> get raw {
    final headers = <Header>[];
    this.headers.forEach((name, values) {
      for (final value in values) {
        headers.add(Header.from(name, value));
      }
    });
    return headers;
  }

  @override
  bool contains(String name) {
    return headers.value(name) != null;
  }

  @override
  String? get(String name) {
    return headers.value(name);
  }

  @override
  List<String> getAll(String name) {
    return headers[name] ?? <String>[];
  }

  @override
  MutableHeaders toMutable() {
    throw UnimplementedError();
  }
}

class AstraHttpRequest implements Request {
  AstraHttpRequest(this.request)
      : chunks = <Uint8List>[],
        received = 0;

  final HttpRequest request;

  final List<Uint8List> chunks;

  int received;

  @override
  Future<List<int>> get body {
    throw UnimplementedError();
  }

  @override
  Headers get headers {
    return AstraHttpHeaders(request);
  }

  @override
  Stream<Uint8List> get stream {
    return request.map<Uint8List>((chunk) {
      chunks.add(chunk);
      return chunk;
    });
  }

  @override
  Future<DataMessage> receive() {
    if (received < chunks.length) {
      return Future<DataMessage>.value(AstraDataMessage(chunks, received));
    }

    return Future<DataMessage>.value(DataMessage.End);
  }
}

class AstraDataMessage implements DataMessage {
  AstraDataMessage(this.chunks, this.index);

  final List<Uint8List> chunks;

  final int index;

  @override
  List<int> get bytes {
    return chunks[index];
  }

  @override
  bool get end => throw UnimplementedError();
}
