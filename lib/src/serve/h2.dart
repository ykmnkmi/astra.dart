library astra.serve.h2;

import 'package:astra/core.dart';
import 'package:http2/multiprotocol_server.dart';

/// A HTTP/2 [Server] backed by a `package:http2/multiprotocol_server.dart` [MultiProtocolHttpServer].
abstract class H2Server extends Server {}
