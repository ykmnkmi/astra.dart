import 'dart:async';

Future<void> main() async {
  final stream = Stream<int>.periodic(Duration(seconds: 1), (tick) => tick + 1);
  final subscription = stream.listen(null);

  final completer = Completer<void>();
  subscription.onData((tick) {
    print('a: $tick');

    if (tick == 3) {
      subscription.pause();
      completer.complete();
    }
  });

  await completer.future;
  subscription.resume();

  subscription.onData((tick) {
    print('b: $tick');
  });
}
