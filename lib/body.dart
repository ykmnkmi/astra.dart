import 'dart:convert';

List<int> bytes([Object content, Encoding encoding = utf8]) {
  if (content == null) {
    return const <int>[];
  }

  if (content is List<int>) {
    return content;
  }

  if (content is String) {
    return encoding.encode(content);
  }

  throw ArgumentError.value(content, 'content');
}
