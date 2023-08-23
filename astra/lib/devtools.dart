library astra.devtools;

import 'dart:async' show Future;
import 'dart:developer' show Service;
import 'dart:isolate' show Isolate;

import 'package:astra/core.dart';
import 'package:vm_service/vm_service.dart' show Event, EventKind, EventStreams;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

/// DevTools extension for [Application].
extension ApplicationDevTools on Application {
  /// Registers hot reloading functionality.
  ///
  /// Sets up a connection to the VM service, listens for isolate reload events,
  /// and triggers the application to reload when such events occur.
  ///
  /// When [done] is provided, the VM service will wait for the future to
  /// done before disposing of the connection.
  Future<void> registerHotReloader([Future<void>? done]) async {
    var isolateId = Service.getIsolateID(Isolate.current);

    if (isolateId == null) {
      return;
    }

    var info = await Service.getInfo();
    var wsUri = info.serverWebSocketUri;

    if (wsUri == null) {
      return;
    }

    var service = await vmServiceConnectUri('$wsUri');
    var isolate = await service.getIsolate(isolateId);
    var groupId = isolate.isolateGroupId;
    await service.streamListen(EventStreams.kIsolate);

    Future<void> onIsolateEvent(Event event) async {
      if (event.kind != EventKind.kIsolateReload) {
        return;
      }

      if (event.isolateGroup case var group? when group.id == groupId) {
        await reload();
      }
    }

    service.onIsolateEvent.listen(onIsolateEvent);

    if (done != null) {
      await done;
      await service.dispose();
    }
  }
}
