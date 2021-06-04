// ignore_for_file: avoid_print

import 'dart:async';

Future<void> main() async {
  final controller = StreamController<int>();
  late final StreamSubscription<int> subscription;
  subscription = controller.stream.listen((data) {
    print('scr: $data');

    if (data == 2) {
      subscription.cancel();
    }
  });

  // subscription.onData();

  <int>[0, 1, 2, 3, 4, 5].forEach(controller.add);
  await controller.done;
}
