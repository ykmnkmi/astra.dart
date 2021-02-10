import 'dart:convert';

import 'package:http2/http2.dart' show Header;
export 'package:http2/http2.dart' show Header;

class Headers {
  Headers({Map<String, String>? headers, List<Header>? raw}) : raw = <Header>[] {
    if (headers != null) {
      assert(raw == null);

      for (final entry in headers.entries) {
        this.raw.add(Header(ascii.encode(entry.key.toLowerCase()), ascii.encode(entry.value)));
      }
    } else if (raw != null) {
      this.raw.addAll(raw);
    }
  }

  List<Header> raw;

  void clear() {
    raw.clear();
  }

  bool contains(String name) {
    final encodedName = ascii.encode(name.toLowerCase());

    for (final pair in raw) {
      if (encodedName == pair.name) {
        return true;
      }
    }

    return false;
  }

  String? get(String name) {
    final encodedName = ascii.encode(name.toLowerCase());

    for (final pair in raw) {
      if (encodedName == pair.name) {
        return ascii.decode(pair.value);
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    final encodedName = ascii.encode(name.toLowerCase());

    return <String>[
      for (final pair in raw)
        if (encodedName == pair.name) ascii.decode(pair.value)
    ];
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw.toList());
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({Map<String, String>? headers, List<Header>? raw}) : super(headers: headers, raw: raw);

  void add(String name, String value) {
    final encodedName = ascii.encode(name.toLowerCase());
    final encodedValue = ascii.encode(value);
    raw.add(Header(encodedName, encodedValue));
  }

  void delete(String name) {
    final encodedName = ascii.encode(name.toLowerCase());
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
    final encodedName = ascii.encode(name.toLowerCase());
    final encodedValue = ascii.encode(value);
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
