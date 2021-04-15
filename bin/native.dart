import 'dart:ffi';

typedef CCall = Void Function(Pointer<NativeFunction<Void Function()>> f);

typedef Call = void Function(Pointer<NativeFunction<Void Function()>> f);

/// Astra bindings to C server.
class AstraNative {
  /// The symbols are looked up in [library].
  factory AstraNative(DynamicLibrary library) {
    return AstraNative.fromLookup(library.lookup);
  }

  /// The symbols are looked up with [lookup].
  AstraNative.fromLookup(Pointer<T> Function<T extends NativeType>(String symbol) lookup)
      : _call = lookup<NativeFunction<CCall>>('call').asFunction<Call>();

  final Call _call;

  void call() {
    final pointer = Pointer.fromFunction<Void Function()>(log);
    _call(pointer);
  }
}

void log() {
  print('hello there!');
}
