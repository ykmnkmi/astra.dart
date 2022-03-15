import 'package:astra/core.dart';

class Servers extends Server {
  Servers(this.base) : servers = <Server>[base];

  final Server base;

  final List<Server> servers;

  @override
  Uri get url {
    return base.url;
  }

  @override
  Future<void> close() async {
    return Future.forEach<Server>(servers, (server) => server.close());
  }

  @override
  void mount(Handler handler) {
    for (var server in servers) {
      server.mount(handler);
    }
  }
}
