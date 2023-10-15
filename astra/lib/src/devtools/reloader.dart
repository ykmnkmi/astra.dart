import 'dart:async' show Future;
import 'dart:developer' show Service;
import 'dart:isolate' show Isolate;

import 'package:astra/src/core/application.dart';
import 'package:astra/src/serve/server.dart';
import 'package:vm_service/vm_service.dart' show Event, EventKind, EventStreams;
import 'package:vm_service/vm_service_io.dart' show vmServiceConnectUri;

/// Registers reloader functionality.
///
/// Sets up a connection to the VM service, listens for isolate reload events,
/// and reloads the application when such events occur.
///
/// When [server] is provided, the VM service will wait for the server to
/// done receiving requests before disposing of the connection.
Future<void> registerReloader(Application application, [Server? server]) async {
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
      await application.reload();
    }
  }

  var subscription = service.onIsolateEvent.listen(onIsolateEvent);

  if (server != null) {
    Future<void> onDone() async {
      await subscription.cancel();
      await service.dispose();
    }

    server.done.whenComplete(onDone);
  }
}
