import 'package:astra/src/core/application.dart';

/// A message that can be sent to a [MessageHub].
final class MessageHubMessage {
  /// Creates a [MessageHubMessage] instance.
  const new(this.value);

  /// The value of the message.
  final Object? value;
}
