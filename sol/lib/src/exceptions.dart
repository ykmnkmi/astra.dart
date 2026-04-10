part of '/sol.dart';

/// Base class for all TCP socket errors.
///
/// Uses a sealed hierarchy so callers can exhaustively match on error types:
///
/// ```dart
/// try {
///   await connection.write(data);
/// } on SocketException catch (error) {
///   switch (error) {
///     case ConnectionClosed():  print('peer disconnected');
///     case WriteFailed():       print('write failed');
///     case InvalidHandle():     print('connection already closed');
///     default:                  print('unexpected: $error');
///   }
/// }
/// ```
sealed class SocketException implements Exception {
  const SocketException(this.message);

  /// Create the appropriate [SocketException] subclass from a native error code.
  ///
  /// All native error codes are negative integers defined in `ffi.dart`.
  factory SocketException.fromCode(int code) {
    return switch (code) {
      ErrorCode.invalidHandle => const InvalidHandle(),
      ErrorCode.invalidAddress => const InvalidAddress(),
      ErrorCode.connectFailed => const ConnectFailed(),
      ErrorCode.bindFailed => const BindFailed(),
      ErrorCode.listenFailed => const ListenFailed(),
      ErrorCode.acceptFailed => const AcceptFailed(),
      ErrorCode.readFailed => const ReadFailed(),
      ErrorCode.writeFailed => const WriteFailed(),
      ErrorCode.closed => const ConnectionClosed(),
      ErrorCode.socketOption => const SocketOptionFailed(),
      ErrorCode.notInitialized => const NotInitialized(),
      ErrorCode.outOfMemory => const OutOfMemory(),
      ErrorCode.invalidArgument => const InvalidArgument(),
      _ => UnknownErrorCode(code),
    };
  }

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() {
    return 'SocketException: $message';
  }

  static void checkResult(int result) {
    if (result < 0) {
      throw SocketException.fromCode(result);
    }
  }
}

/// The handle does not refer to a valid open socket.
final class InvalidHandle extends SocketException {
  const InvalidHandle() : super('invalid or closed handle');
}

/// The address bytes could not be parsed as IPv4 or IPv6.
final class InvalidAddress extends SocketException {
  const InvalidAddress() : super('invalid address format');
}

/// The TCP connection attempt failed.
final class ConnectFailed extends SocketException {
  const ConnectFailed() : super('connection failed');
}

/// Could not bind to the requested address/port.
final class BindFailed extends SocketException {
  const BindFailed() : super('bind failed');
}

/// Could not start listening on the socket.
final class ListenFailed extends SocketException {
  const ListenFailed() : super('listen failed');
}

/// Could not accept an incoming connection.
final class AcceptFailed extends SocketException {
  const AcceptFailed() : super('accept failed');
}

/// A read operation failed.
final class ReadFailed extends SocketException {
  const ReadFailed() : super('read failed');
}

/// A write operation failed.
final class WriteFailed extends SocketException {
  const WriteFailed() : super('write failed');
}

/// The remote peer closed the connection (EOF).
///
/// This is a normal condition — it means the peer called `close()` or
/// `closeWrite()`. [Connection.read] converts this to a `null` return
/// rather than throwing.
final class ConnectionClosed extends SocketException {
  const ConnectionClosed() : super('connection closed by peer');
}

/// A `getsockopt` or `setsockopt` call failed.
final class SocketOptionFailed extends SocketException {
  const SocketOptionFailed() : super('socket option operation failed');
}

/// The library has not been initialized.
///
/// This should not occur in normal usage since IO service calls `tcp_init`
/// automatically. If you see this, the native library failed to load or
/// initialize.
final class NotInitialized extends SocketException {
  const NotInitialized() : super('library not initialized');
}

/// A native memory allocation failed.
final class OutOfMemory extends SocketException {
  const OutOfMemory() : super('out of memory');
}

/// An argument was invalid.
final class InvalidArgument extends SocketException {
  const InvalidArgument() : super('invalid argument');
}

/// An error code that doesn't map to any known constant.
final class UnknownErrorCode extends SocketException {
  const UnknownErrorCode(this.code) : super('unknown error (code $code)');

  /// The raw native error code.
  final int code;
}
