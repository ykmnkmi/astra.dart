import 'dart:ffi';

typedef _c_add = Int32 Function(Int32 a, Int32 b);

typedef _dart_add = int Function(int a, int b);

/// Astra bindings to C server.
class AstraNative {
  /// The symbols are looked up in [library].
  factory AstraNative(DynamicLibrary library) {
    return AstraNative.fromLookup(library.lookup);
  }

  /// The symbols are looked up with [lookup].
  AstraNative.fromLookup(Pointer<T> Function<T extends NativeType>(String symbol) lookup)
      : _add = lookup<NativeFunction<_c_add>>('add').asFunction<_dart_add>();

  final _dart_add _add;

  int add(int a, int b) {
    return _add(a, b);
  }
}
