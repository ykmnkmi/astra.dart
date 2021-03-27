import 'dart:async';

Future<void> main(List<String> arguments) async {
  final stream = Stream<int>.periodic(Duration(milliseconds: 1100), (i) => i > 5 ? -1 : i);
  final iterable = StreamIterator<int>(stream);

  Future<int> receive() {
    return iterable.moveNext().then((hasNext) => hasNext ? iterable.current : -1);
  }

  while (true) {
    final i = await receive();

    if (i < 0) {
      break;
    }

    print('received: $i');
    await Future<void>.delayed(Duration(milliseconds: 500));
  }
}
