part of '/solus.dart';

extension type const ErrorCode._(int _) {
  /// Invalid or closed handle
  static const ErrorCode invalidHandle = ErrorCode._(-1);

  /// Invalid address format
  static const ErrorCode invalidAddress = ErrorCode._(-2);

  /// Connection failed
  static const ErrorCode connectFailed = ErrorCode._(-3);

  /// Bind failed
  static const ErrorCode bindFailed = ErrorCode._(-4);

  /// Listen failed
  static const ErrorCode listenFailed = ErrorCode._(-5);

  /// Accept failed
  static const ErrorCode acceptFailed = ErrorCode._(-6);

  /// Read failed
  static const ErrorCode readFailed = ErrorCode._(-7);

  /// Write failed
  static const ErrorCode writeFailed = ErrorCode._(-8);

  /// Connection closed by peer
  static const ErrorCode closed = ErrorCode._(-9);

  /// Socket option operation failed
  static const ErrorCode socketOption = ErrorCode._(-10);

  /// Library not initialized
  static const ErrorCode notInitialized = ErrorCode._(-11);

  /// Memory allocation failed
  static const ErrorCode outOfMemory = ErrorCode._(-12);

  /// Invalid argument
  static const ErrorCode invalidArgument = ErrorCode._(-13);
}
