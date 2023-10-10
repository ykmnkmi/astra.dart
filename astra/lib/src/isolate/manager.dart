import 'dart:async' show Completer, Future, FutureOr;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;

class IsolateManager {
  IsolateManager(
    Isolate isolate,
    SendPort serverPort,
    Completer<void> stopCompleter,
  )   : _isolate = isolate,
        _serverPort = serverPort,
        _stopCompleter = stopCompleter;

  final Isolate _isolate;

  final SendPort _serverPort;

  final Completer<void> _stopCompleter;

  Future<void> stop({bool force = false}) async {
    if (_stopCompleter.isCompleted) {
      return;
    }

    _serverPort.send(force);
    await _stopCompleter.future;
  }

  Future<void> kill() async {
    _isolate.kill();
    await _stopCompleter.future;
  }

  static Future<IsolateManager> spawn(
    FutureOr<void> Function(SendPort?) create, [
    String? debugName,
  ]) async {
    var receivePort = ReceivePort();
    var sendPort = receivePort.sendPort;
    var launchCompleter = Completer<void>();
    var stopCompleter = Completer<void>();
    late SendPort serverPort;

    void onMessage(Object? message) {
      switch (message) {
        case SendPort():
          serverPort = message;
          launchCompleter.complete();
          break;
        case null: // on exit
          receivePort.close();
          stopCompleter.complete();
          break;
        case [Object error, StackTrace stackTrace]: // on error
          stopCompleter.completeError(error, stackTrace);
          break;
        default:
          // TODO(isolate): add error message
          throw UnsupportedError('');
      }
    }

    receivePort.listen(onMessage);

    var isolate = await Isolate.spawn<SendPort>(create, sendPort,
        onExit: sendPort, onError: sendPort, debugName: debugName);
    await launchCompleter.future;
    return IsolateManager(isolate, serverPort, stopCompleter);
  }
}
