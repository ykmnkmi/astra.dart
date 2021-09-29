import 'dart:async' show StreamController, StreamSubscription;
import 'dart:io' show Socket;

import 'line_splitter.dart';

class Parser extends Stream<List<int>> {
  Parser(this.socket) : controller = StreamController<List<int>>(sync: true) {
    controller.onCancel = () {
      socketSubscription?.cancel();
    };

    socketSubscription = const LineSplitter()
        .bind(socket)
        .listen(onData, onError: controller.addError, onDone: onDone);
  }

  final Socket socket;

  final StreamController<List<int>> controller;

  StreamSubscription<List<int>>? socketSubscription;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void onData(List<int> data) {
    controller.sink.add(data);
  }

  void onDone() {
    socketSubscription = null;
  }
}
