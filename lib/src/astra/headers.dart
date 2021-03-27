part of '../../astra.dart';

class Headers {
  Headers({Map<String, String>? headers, List<Header>? raw}) {
    if (headers != null) {
      assert(raw == null);
      _raw = <Header>[];

      for (final entry in headers.entries) {
        _raw!.add(Header.ascii(entry.key.toLowerCase(), entry.value));
      }
    } else if (raw != null) {
      _raw = raw;
    } else {
      _raw = <Header>[];
    }
  }

  List<Header>? _raw;

  List<Header> get raw => _raw!;

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
