import 'dart:async' show Future;
import 'dart:developer' show Service;
import 'dart:isolate' show Isolate;

import 'package:vm_service/vm_service.dart'
    show Event, EventKind, EventStreams, VmService;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

VmService? _service;

Future<VmService?> _getService() async {
  if (_service != null) {
    return _service;
  }

  var isolateId = Service.getIsolateID(Isolate.current);

  if (isolateId == null) {
    return null;
  }

  var info = await Service.getInfo();
  var wsUri = info.serverWebSocketUri;

  if (wsUri == null) {
    return null;
  }

  _service = await vmServiceConnectUri('$wsUri');
  return _service;
}

/// Registers a hot-reloading callback with the Dart VM service.
///
/// The [callback] function will be invoked whenever the current isolate is
/// reloaded. Hot-reloading allows you to update code without restarting the
/// application.
///
/// Ensure that the Dart VM service is enabled for hot-reloading to work.
///
/// Pass a [doneFuture] to dispose of the VM service when the callback is no
/// longer needed, helping to release resources.
///
/// Returns `true` if the hot-reloading callback was successfully registered, or
/// `false` if the VM service is not available.
Future<bool> registerHotReloader(
  Future<void> Function() callback, [
  Future<void>? doneFuture,
]) async {
  var service = await _getService();

  if (service == null) {
    return false;
  }

  var isolateId = Service.getIsolateID(Isolate.current);

  if (isolateId == null) {
    return false;
  }

  var isolate = await service.getIsolate(isolateId);
  var groupId = isolate.isolateGroupId;
  await service.streamListen(EventStreams.kIsolate);

  Future<void> onIsolateEvent(Event event) async {
    if (event.kind != EventKind.kIsolateReload) {
      return;
    }

    if (event.isolateGroup case var group? when group.id == groupId) {
      await callback();
    }
  }

  var subscription = service.onIsolateEvent.listen(onIsolateEvent);

  if (doneFuture case var future?) {
    Future<void> onDone() async {
      await subscription.cancel();
      await service.dispose();
      _service = null;
    }

    future.whenComplete(onDone);
  }

  return true;
}
