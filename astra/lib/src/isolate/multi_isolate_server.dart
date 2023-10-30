import 'dart:async' show Completer, Future;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/isolate/isolate_server.dart';
import 'package:astra/src/isolate/isolate_supervisor.dart';
import 'package:astra/src/serve/server.dart';
import 'package:logging/logging.dart' show Logger;

final class MultiIsolateServer implements Server {
  MultiIsolateServer(
    this.url,
    SupervisorManager supervisorManager, {
    this.logger,
  })  : _supervisorManager = supervisorManager,
        _doneCompleter = Completer<void>();

  final SupervisorManager _supervisorManager;

  final Completer<void> _doneCompleter;

  @override
  Application? get application {
    // TODO(isolate): add error message
    throw UnsupportedError('');
  }

  @override
  final Logger? logger;

  @override
  final Uri url;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> mount(Application application) {
    // TODO(isolate): add error message
    throw UnsupportedError('');
  }

  Future<void> reload() async {
    await _supervisorManager.reload();
  }

  @override
  Future<void> close({bool force = false}) async {
    if (_doneCompleter.isCompleted) {
      return;
    }

    await _supervisorManager.stop(force: force);
    _doneCompleter.complete();
  }

  static Future<MultiIsolateServer> spawn(
    Uri url,
    int isolates,
    Future<IsolateServer> Function(SendPort controlPort) create, {
    Logger? logger,
  }) async {
    var supervisorManager = SupervisorManager(logger);
    await supervisorManager.start(isolates, create);
    return MultiIsolateServer(url, supervisorManager, logger: logger);
  }
}
