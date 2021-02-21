part of '../../astra.dart';

abstract class Message {
  bool get end;
}

abstract class HeadersMessage implements Message {
  List<Header> get headers;
}

abstract class DataMessage implements Message {
  static const DataMessage End = DataEndMessage();

  List<int> get bytes;
}

class DataEndMessage implements DataMessage {
  const DataEndMessage();

  @override
  List<int> get bytes {
    return const <int>[];
  }

  @override
  bool get end {
    return true;
  }
}
