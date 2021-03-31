import 'dart:convert' show ascii;

import 'package:http2/http2.dart' show Header;

export 'package:http2/http2.dart' show DataStreamMessage, Header, HeadersStreamMessage, StreamMessage;

abstract class ContentTypes {
  static const String text = 'text/plain; charset=utf-8';

  static const String html = 'text/html; charset=utf-8';

  static const String json = 'application/json; charset=utf-8';
}

class Headers {
  Headers({List<Header>? raw}) : _raw = <Header>[] {
    if (raw != null) {
      _raw.addAll(raw);
    }
  }

  final List<Header> _raw;

  List<Header> get raw => _raw;

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

    for (final header in raw.reversed) {
      if (equals(encodedName, header.name)) {
        return ascii.decode(header.value);
      }
    }

    return null;
  }

  List<String> getAll(String name) {
    final encodedName = ascii.encode(name.toLowerCase());

    return <String>[
      for (final header in raw)
        if (equals(encodedName, header.name)) ascii.decode(header.value)
    ];
  }

  MutableHeaders toMutable() {
    return MutableHeaders(raw: raw.toList());
  }
}

class MutableHeaders extends Headers {
  MutableHeaders({List<Header>? raw}) : super(raw: raw);

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
      if (equals(encodedName, raw[index].name)) {
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

bool equals(List<int>? list1, List<int>? list2) {
  if (identical(list1, list2)) {
    return true;
  }

  if (list1 == null || list2 == null) {
    return false;
  }

  final length = list1.length;

  if (length != list2.length) {
    return false;
  }

  for (var i = 0; i < length; i++) {
    if (list1[i] != list2[i]) {
      return false;
    }
  }

  return true;
}
