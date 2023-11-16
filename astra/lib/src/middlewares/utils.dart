import 'package:stack_trace/stack_trace.dart' show Frame;

/// Whether this stack frame comes from the Dart core, `shelf` or `astra`
/// libraries.
bool isCoreFrame(Frame frame) {
  return frame.isCore || frame.package == 'shelf' || frame.package == 'astra';
}
