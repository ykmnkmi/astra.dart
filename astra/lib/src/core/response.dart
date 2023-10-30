import 'package:shelf/shelf.dart' show Response;

export 'package:shelf/shelf.dart' show Response;

/// An extension on the [Response] class that provides additional functionality.
extension ResponseExtension on Response {
  /// Determines if the [Response] should buffer its output.
  ///
  /// This method returns `true` if the response should buffer its output,
  /// allowing content to be sent incrementally. If buffering is not needed,
  /// it returns `false`. The buffering behavior can be configured using the
  /// `shelf` context's 'shelf.io.buffer_output' key.
  bool? get bufferOutput => context['shelf.io.buffer_output'] as bool?;
}
