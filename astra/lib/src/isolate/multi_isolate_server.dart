import 'dart:async' show Future;
import 'dart:isolate' show SendPort;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/isolate/isolate_supervisor.dart';
import 'package:astra/src/serve/server.dart';

final class MultiIsolateServer extends Server {
  MultiIsolateServer(
    super.address,
    super.port, {
    super.securityContext,
    super.backlog,
    super.v6Only,
    super.requestClientCertificate,
    super.shared,
    super.identifier,
    super.logger,
  }) : _supervisorManager = SupervisorManager();

  final SupervisorManager _supervisorManager;

  @override
  // TODO(isolate): Update error message.
  Application? get application => throw UnsupportedError('');

  @override
  bool get isRunning => _supervisorManager.isRunning;

  // TODO(serve): Bind stub server to get actual address and port.
  Future<void> start(
    int isolates,
    Future<Server> Function(SendPort) create,
  ) async {
    await _supervisorManager.start(isolates, create);
  }

  @override
  Future<void> handle(Handler handler) {
    // TODO(isolate): Update error message.
    throw UnsupportedError('');
  }

  @override
  Future<void> mount(Application application) async {
    // TODO(isolate): Update error message.
    throw UnsupportedError('');
  }

  Future<void> reload() async {
    await _supervisorManager.reload();
  }

  @override
  Future<void> close({bool force = false}) async {
    await _supervisorManager.stop(force: force);
  }
}
