import 'dart:io';

abstract class Server {
  Server(this.address, this.port,
      {this.context, this.backlog = 0, this.shared = false, this.v6Only = false});

  final Object address;

  final int port;

  final SecurityContext? context;

  final int backlog;

  final bool shared;

  final bool v6Only;

  Uri get url {
    var scheme = context == null ? 'http' : 'https';
    var address = this.address;
    String host;

    if (address is InternetAddress) {
      if (address.isLoopback) {
        host = 'localhost';
      } else {
        if (address.type == InternetAddressType.IPv6) {
          host = '[${address.address}]';
        } else {
          host = address.address;
        }
      }
    } else if (address is String) {
      host = address;
    } else {
      throw TypeError();
    }

    return Uri(scheme: scheme, host: host, port: port);
  }

  Future<void> start();

  Future<void> close();
}
