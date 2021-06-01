import 'dart:async' show FutureOr;

import 'request.dart';
import 'types.dart';

abstract class Controller {
  FutureOr<void> call(Request request, Start start, Respond respond);
}
