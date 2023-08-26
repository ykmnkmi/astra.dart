import 'package:shelf_client/src/client.dart';

/// An [Client] exception.
class ClientException implements Exception {
  ClientException(this.message, [this.uri]);

  final String message;

  /// The URL of the HTTP request or response that failed.
  final Uri? uri;

  @override
  String toString() {
    if (uri == null) {
      return 'ClientException: $message';
    }

    return 'ClientException: $message, uri=$uri';
  }
}
