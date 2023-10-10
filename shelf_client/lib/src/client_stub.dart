import 'package:shelf/shelf.dart' show Pipeline;
import 'package:shelf_client/src/client.dart';

/// Create an [Client].
Client createClient({Pipeline? pipeline}) {
  throw UnsupportedError('Cannot create a client without dart:io.');
}
