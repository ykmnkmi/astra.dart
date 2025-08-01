import 'package:astra/src/core/application.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/serve/server.dart';
import 'package:http/http.dart'
    as http
    show
        BaseRequest,
        MultipartRequest,
        Request,
        StreamedRequest,
        StreamedResponse;
import 'package:http/http.dart' show BaseClient;
import 'package:http/io_client.dart' show IOClient;

/// A test client for making HTTP requests to a server.
base class TestClient extends BaseClient {
  /// Creates instance of [TestClient].
  TestClient({this.host = 'localhost', this.port = 8282})
    : assert(host.isNotEmpty, 'host cannot be empty'),
      assert(port != 0, 'port cannot be 0.'),
      _client = IOClient();

  Server? _server;

  final IOClient _client;

  /// The host that the underlying server is listening on.
  final String host;

  /// The port that the underlying server is listening on.
  final int port;

  /// Mounts [Handler] to this client.
  Future<void> handle(Handler handler) async {
    if (_server case var server?) {
      await server.close();
    }

    _server = await Server.bind(handler, host, port);
  }

  /// Mounts [Application] to this client.
  Future<void> mount(Application application) async {
    if (_server case var server?) {
      await server.close();
    }

    _server = await ApplicationServer.bind(application, host, port);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var newUrl = request.url.replace(scheme: 'http', host: host, port: port);

    http.BaseRequest newRequest;

    if (request is http.Request) {
      newRequest = http.Request(request.method, newUrl)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
    } else if (request is http.MultipartRequest) {
      newRequest = http.MultipartRequest(request.method, newUrl)
        ..headers.addAll(request.headers)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
    } else if (request is http.StreamedRequest) {
      newRequest = http.StreamedRequest(request.method, newUrl)
        ..headers.addAll(request.headers)
        ..sink.addStream(request.finalize());
    } else {
      throw TypeError();
    }

    return await _client.send(newRequest);
  }

  @override
  Future<void> close() async {
    _client.close();

    if (_server case var server?) {
      await server.close();
    }

    super.close();
  }
}
