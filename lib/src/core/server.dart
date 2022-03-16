import 'dart:io';

import 'package:astra/core.dart';

abstract class Server {
  Server(this.address, this.port,
      {this.context, this.backlog = 0, this.shared = false, this.v6Only = false});

  final InternetAddress address;

  final int port;

  final SecurityContext? context;

  final int backlog;

  final bool shared;

  final bool v6Only;

  Uri get url {
    var scheme = context == null ? 'http' : 'https';
    var host = address.isLoopback
        ? 'localhost'
        : address.type == InternetAddressType.IPv6
            ? '[${address.address}]'
            : address.address;
    return Uri(scheme: scheme, host: host, port: port);
  }

  Future<void> start();

  Future<void> close();

  void mount(Handler handler);
}
