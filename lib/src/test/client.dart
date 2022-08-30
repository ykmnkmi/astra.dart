import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart' show Handler;
import 'package:astra/serve.dart' show ServeHandlerExtension;
import 'package:http/http.dart' show BaseClient, BaseRequest, ClientException, StreamedResponse;
import 'package:http/io_client.dart' show IOStreamedResponse;

class TestClient extends BaseClient {
  TestClient(this.handler, {this.host = 'localhost', this.port = 0, this.context})
      : scheme = context == null ? 'http' : 'https',
        client = HttpClient(context: context);

  final Handler handler;

  final String scheme;

  final String host;

  final int port;

  final SecurityContext? context;

  final HttpClient client;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    var server = await handler.serve(host, port, securityContext: context);
    var stream = request.finalize();
    StreamedResponse streamedResponse;

    try {
      var requestedUrl = request.url;
      var url = requestedUrl.replace(
          scheme: requestedUrl.scheme.isEmpty ? scheme : requestedUrl.scheme,
          host: requestedUrl.host.isEmpty ? host : requestedUrl.host,
          port: port == 0 ? server.port : requestedUrl.port);
      var clientRequest = await client.openUrl(request.method, url);

      clientRequest
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..contentLength = (request.contentLength ?? -1)
        ..persistentConnection = request.persistentConnection;

      request.headers.forEach(clientRequest.headers.set);

      await clientRequest.addStream(stream);

      var response = await clientRequest.close();
      var headers = <String, String>{};

      void action(String key, List<String> values) {
        headers[key] = values.join(',');
      }

      response.headers.forEach(action);

      streamedResponse = IOStreamedResponse(response, response.statusCode,
          contentLength: response.contentLength == -1 ? null : response.contentLength,
          request: request,
          headers: headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
          inner: response);
    } on HttpException catch (error) {
      throw ClientException(error.message, error.uri);
    }

    await server.close(force: true);
    return streamedResponse;
  }
}
