import 'dart:convert' show ascii;

import 'package:http2/http2.dart' show Header;

abstract class ContentTypes {
  static const String text = 'text/plain; charset=utf-8';

  static const String html = 'text/html; charset=utf-8';

  static const String json = 'application/json; charset=utf-8';
}

class Headers {
  Headers({Map<String, String>? headers, List<Header>? raw}) {
    if (headers != null) {
      assert(raw == null);
      raw = <Header>[];

      for (final entry in headers.entries) {
        raw.add(Header.ascii(entry.key.toLowerCase(), entry.value));
      }
    } else if (raw != null) {
      raw = raw;
    } else {
      raw = <Header>[];
    }
  }

  late List<Header> raw;

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
    raw.add(Header.ascii(name, value));
  }

  void clear() {
    raw.clear();
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
