import 'dart:ffi';
import 'dart:io' show InternetAddress;
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:solus/src/ffi.dart';

Future<void> main() async {
  if (tcp_init(NativeApi.initializeApiDLData) != 0) {
    throw StateError('initialization failed');
  }

  var receivePort = ReceivePort('native');
  var sendPort = receivePort.sendPort;
  var nativePort = sendPort.nativePort;

  var addr = calloc<Uint8>(4);
  addr.asTypedList(4).setRange(0, 4, InternetAddress.loopbackIPv4.rawAddress);

  var result = tcp_listen(nativePort, 0, addr, 4, 8080, false, 0, false);

  if (result == 0) {
    var first = await receivePort.first;
    var handle = first as int;
    print(handle);
    print(tcp_listener_close(1, handle, false));
  }

  receivePort.close();
}
