import 'package:shelf/shelf.dart' show Response;

export 'package:shelf/shelf.dart' show Response;

/// An extension on the [Response] class.
extension ResponseExtension on Response {
  /// Returns `true` if the [Response] should buffer output.
  bool? get bufferOutput {
    return context['shelf.io.buffer_output'] as bool?;
  }
}
