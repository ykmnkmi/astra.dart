import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:astra/serve.dart';
import 'package:path/path.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:vm_service/vm_service_io.dart';

import '__PACKAGE__' as _ show __TARGET__;

Future<void> create(SendPort sendPort) async {
  ApplicationManager.setup();

  var handler = await getHandler(_.__TARGET__);
  var server = await IsolateServer.start(sendPort, '__HOST__', __PORT__, //
      context: __CONTEXT__,
      backlog: __BACKLOG__,
      shared: __SHARED__,
      v6Only: __V6ONLY__);
  server.mount(handler);
}

Future<void> main() async {
  if (__OBSERVE__) {
    var info = await Service.getInfo();
    var uri = info.serverUri;

    if (uri == null) {
      // TODO: update error
      throw StateError('observe: no server uri');
    }

    stdout.writeln('* observatory listening on $uri');
  }

  var shutdown = <FutureOr<void> Function()>[];
  var supervisors = <IsolateSupervisor>[];

  for (var i = 0; i < __CONCURRENCY__; i += 1) {
    var supervisor = IsolateSupervisor(create, 'isolate/${i + 1}');
    stdout.writeln('* starting isolate/${i + 1}');
    await supervisor.init();
    supervisors.add(supervisor);
    shutdown.add(supervisor.stop);
  }

  if (__CONCURRENCY__ > 1) {
    stdout.writeln('* all isolates started');
  }

  if (__RELOAD__) {
    var info = await Service.getInfo();
    var uri = info.serverWebSocketUri;

    if (uri == null) {
      // TODO: update error
      throw StateError('reload: no vm service ws uri');
    }

    var service = await vmServiceConnectUri(uri.toString());
    shutdown.add(service.dispose);

    var isolateIds = <String>[];

    for (var supervisor in supervisors) {
      var id = Service.getIsolateID(supervisor.isolate);

      if (id == null) {
        // TODO: update error
        throw StateError('${supervisor.name} id == null');
      }

      isolateIds.add(id);
    }

    var directory = Directory('lib');

    Future<void> reloading(FileSystemEvent event) async {
      stdout.writeln('* reloading...');

      Future<void> onEach(String isolateId) async {
        var result = await service.reloadSources(isolateId);

        if (result.success == true) {
          await service.callServiceExtension('ext.astra.reasemble', isolateId: isolateId);
        }
      }

      return Future.forEach<String>(isolateIds, onEach);
    }

    void reloaded(Object? message) {
      if (__CONCURRENCY__ > 1) {
        stdout.writeln('* __CONCURRENCY__ isolate(s) reloaded');
      } else {
        stdout.writeln('* isolate reloaded');
      }
    }

    var watch = directory
        .watch(events: FileSystemEvent.modify, recursive: true)
        .throttle(Duration(seconds: 1))
        .asyncMapSample<void>(reloading)
        .listen(reloaded);
    shutdown.add(watch.cancel);
    stdout.writeln('* watching ${toUri(directory.path).toFilePath(windows: false)}');
  }

  var sigint = ProcessSignal.sigint.watch().listen(null);

  void onSignal(ProcessSignal signal) {
    for (var callback in shutdown.reversed) {
      callback();
    }
  }

  shutdown.add(sigint.cancel);
  sigint.onData(onSignal);
  stdout.writeln('* serving at __SCHEME__://__HOST__:__PORT__');
}
