import 'dart:async';

import 'package:shelf/shelf.dart';

abstract class Application {
  FutureOr<Response> call(Request request);
}
