import 'dart:io';

String join(String arg1, String arg2, [String? arg3]) {
  var result = arg1 + Platform.pathSeparator + arg2;

  if (arg3 == null) {
    return result;
  }

  return result + Platform.pathSeparator + arg3;
}
