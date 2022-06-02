import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart' show Handler;
import 'package:astra/serve.dart' show serve;
import 'package:http/http.dart' show BaseClient, BaseRequest, Response, StreamedResponse;

typedef TestClientCallback = Future<void> Function(TestClient client);

Future<void> withTestClient(Handler handler, TestClientCallback callback) async {
  var client = TestClient(handler);
  await callback(client);
  client.close();
}

class TestClient extends BaseClient {
  TestClient(this.handler, {this.host = 'localhost', this.port = 3000, this.securityContext})
      : scheme = securityContext == null ? 'http' : 'https';

  final Handler handler;

  final String scheme;

  final String host;

  final int port;

  final SecurityContext? securityContext;

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) {
    url = url.replace(scheme: scheme, host: host, port: port);
    return super.get(url, headers: headers);
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    var server = await serve(handler, host, port, securityContext: securityContext);
    var response = await request.send();
    await server.close();
    return response;
  }
}
