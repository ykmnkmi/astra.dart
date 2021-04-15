import 'dart:ffi';

import 'native.dart';

void main(List<String> arguments) {
  final library = DynamicLibrary.open('./bin/native.so');
  final native = AstraNative.fromLookup(library.lookup);
  native.call();
}
