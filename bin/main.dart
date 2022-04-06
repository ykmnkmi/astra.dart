import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:astra/core.dart';
import 'package:astra/isolate.dart';
import 'package:astra/serve.dart';
import 'package:path/path.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:vm_service/vm_service_io.dart';

const String __SCHEME__ = __CONTEXT__ == null ? 'http' : 'https';
const String __ADDRESS__ = 'localhost';
const int __PORT__ = 3000;
const SecurityContext? __CONTEXT__ = null;
const int __BACKLOG__ = 0;
const bool __SHARED__ = __CONCURRENCY__ > 1;
const bool __V6ONLY__ = false;
const bool __OBSERVE__ = false;
const int __CONCURRENCY__ = 1;
const bool __RELOAD__ = false;

class Hello extends Application {
  int count = 0;

  @override
  Handler get entryPoint => handler;

  Future<Response> handler(Request request) async {
    count += 1;

    switch (request.url.path) {
      case '':
        return Response.ok('hello world!');
      case 'count':
        return Response.ok('count: $count');
      case 'readme':
        return Response.ok(File('README.md').openRead());
      case 'error':
        throw Exception('some message');
      default:
        return Response.notFound('Request for "${request.url}"');
    }
  }

  @override
  void reload() {
    count = 0;
  }
}

Future<void> create(SendPort sendPort) async {
  var server = await H11IOServer.bind('__ADDRESS__', __PORT__, //
      securityContext: __CONTEXT__,
      backlog: __BACKLOG__,
      shared: __SHARED__,
      v6Only: __V6ONLY__);
  ApplicationIsolateServer(Hello(), server, sendPort).start();
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
    var rescivePort = RawReceivePort();
    var isolate = await Isolate.spawn(create, rescivePort.sendPort, //
        paused: true,
        errorsAreFatal: false,
        onError: rescivePort.sendPort,
        debugName: 'isolate/${i + 1}');
    var supervisor = IsolateSupervisor(isolate, rescivePort, i);
    stdout.writeln('* starting isolate/${i + 1}');
    await supervisor.resume();
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
      throw Exception('reload: no vm service ws uri');
    }

    var service = await vmServiceConnectUri(uri.toString());
    shutdown.add(service.dispose);

    var isolateIds = <String>[];

    for (var supervisor in supervisors) {
      var id = Service.getIsolateID(supervisor.isolate);

      if (id == null) {
        // TODO: update error
        throw Exception('isolate/${supervisor.identifier} id == null');
      }

      isolateIds.add(id);
    }

    var directory = Directory('lib');

    Future<void> reloading(FileSystemEvent event) async {
      stdout.writeln('* reloading...');

      Future<void> onEach(String isolateId) async {
        var result = await service.reloadSources(isolateId);

        if (result.success == true) {
          await service.callServiceExtension('ext.astra.reload', isolateId: isolateId);
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
  stdout.writeln('* serving at $__SCHEME__://$__ADDRESS__:$__PORT__');
}
