import 'dart:convert';

import 'package:http2/http2.dart' show Header;
export 'package:http2/http2.dart' show Header;

class Headers {
  Headers({Map<String, Object> scope, Map<String, String> headers, List<Header> raw}) {
    if (headers != null) {
      assert(scope == null);
      assert(raw == null);
      this.raw = <Header>[for (final name in headers.keys) Header(latin1.encode(name.toLowerCase()), latin1.encode(headers[name]))];
    } else if (raw != null) {
      assert(scope == null);
      this.raw = raw;
    } else if (scope != null) {
      this.raw = scope['headers'] as List<Header>;
    } else {
      this.raw = <Header>[];
    }
  }

  List<Header> raw;

  void clear() {
    raw.clear();
  }

  bool contains(String name) {
    final encodedName = latin1.encode(name.toLowerCase());

    for (final pair in raw) {
      if (encodedName == pair.name) {
        return true;
      }
    }

    return false;
  }

  String get(String name) {
    final encodedName = latin1.encode(name.toLowerCase());

    for (final pair in raw) {
      if (encodedName == pair.name) {
        return latin1.decode(pair.value);
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    final encodedName = latin1.encode(name.toLowerCase());

    return <String>[
      for (final pair in raw)
        if (encodedName == pair.name) latin1.decode(pair.value)
    ];
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw.toList());
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({Map<String, Object> scope, Map<String, String> headers, List<Header> raw}) : super(scope: scope, headers: headers, raw: raw);

  void add(String name, String value) {
    final encodedName = latin1.encode(name.toLowerCase());
    final encodedValue = latin1.encode(value);
    raw.add(Header(encodedName, encodedValue));
  }

  void delete(String name) {
    final encodedName = latin1.encode(name.toLowerCase());
    final indexes = <int>[];

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (encodedName == raw[index].name) {
        indexes.add(index);
      }
    }

    for (final index in indexes) {
      raw.removeAt(index);
    }
  }

  void set(String name, String value) {
    final encodedName = latin1.encode(name.toLowerCase());
    final encodedValue = latin1.encode(value);
    final indexes = <int>[];

    for (var index = raw.length - 1; index >= 0; index -= 1) {
      if (encodedName == raw[index].name) {
        indexes.add(index);
      }
    }

    if (indexes.isEmpty) {
      raw.add(Header(encodedName, encodedValue));
    } else {
      final header = raw[indexes.removeLast()];
      raw[indexes.removeLast()] = Header(header.name, encodedValue);

      for (final index in indexes) {
        raw.removeAt(index);
      }
    }
  }
}
