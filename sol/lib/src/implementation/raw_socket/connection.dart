import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:sol/sol.dart';

/// Adapts a [RawSocket] to the [Connection] interface.
///
/// The core challenge is the impedance mismatch between [RawSocket]'s
/// stream-of-events model and [Connection]'s Future-per-operation model.
/// We bridge them with one [Completer] per direction (read / write),
/// resolved from the stream subscription whenever the socket signals
/// readiness.
///
/// Both [RawSocket.readEventsEnabled] and [RawSocket.writeEventsEnabled] start
/// as `false`. Events are armed only for the duration that a completer is
/// parked, then disarmed immediately on delivery. This keeps the subscription
/// quiet during idle periods and prevents the continuous write-event
/// flooding that [RawSocket] emits while the send buffer has room.
final class RawSocketConnection implements Connection {
  RawSocketConnection(this.socket) {
    // Disarm both directions up front. We re-enable them on demand,
    // only when a completer is waiting for a particular event.
    socket.readEventsEnabled = false;
    socket.writeEventsEnabled = false;

    // A single long-lived subscription drives the whole connection lifetime.
    // One subscriber prevents two listeners from racing on the same events.
    subscription = socket.listen(
      onEvent,
      onError: (Object error, StackTrace stack) {
        readCompleter?.completeError(error, stack);
        readCompleter = null;
        writeCompleter?.completeError(error, stack);
        writeCompleter = null;
      },
      onDone: () {
        // Stream ended — treat as EOF for any pending read.
        readCompleter?.complete(null);
        readCompleter = null;
        writeCompleter?.completeError(const WriteFailed());
        writeCompleter = null;
      },
    );
  }

  final RawSocket socket;
  late final StreamSubscription<RawSocketEvent> subscription;

  // At most one outstanding completer per direction at any moment.
  Completer<Uint8List?>? readCompleter;
  Completer<void>? writeCompleter;

  // ── Event dispatch ──────────────────────────────────────────────────────

  void onEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.read:
        // Disarm before completing. If we did it after, the continuation
        // could call read() again synchronously, re-arm, and we'd risk a
        // spurious second event sneaking through before we return.
        socket.readEventsEnabled = false;

        var completer = readCompleter;

        if (completer == null) {
          break;
        }

        var data = socket.read();

        if (data != null && data.isNotEmpty) {
          readCompleter = null;
          completer.complete(Uint8List.fromList(data));
        } else {
          // Empty or null despite the event, this is a spurious wakeup
          // (the spec doesn't prohibit them). Stay parked and re-arm so
          // the next event gets another chance. The completer is unchanged.
          socket.readEventsEnabled = true;
        }

      case RawSocketEvent.readClosed:
      case RawSocketEvent.closed:
        socket.readEventsEnabled = false;
        readCompleter?.complete(null);
        readCompleter = null;
        writeCompleter?.completeError(const ConnectionClosed());
        writeCompleter = null;

      case RawSocketEvent.write:
        // Same disarm-before-complete discipline as on the read side.
        socket.writeEventsEnabled = false;
        writeCompleter?.complete();
        writeCompleter = null;

      default:
        break;
    }
  }

  // ── Connection interface ────────────────────────────────────────────────

  @override
  InternetAddress get address => socket.address;

  @override
  int get port => socket.port;

  @override
  InternetAddress get remoteAddress => socket.remoteAddress;

  @override
  int get remotePort => socket.remotePort;

  @override
  bool get keepAlive => throw UnimplementedError();

  @override
  set keepAlive(bool enabled) {
    throw UnimplementedError();
  }

  @override
  bool get noDelay => throw UnimplementedError();

  @override
  set noDelay(bool enabled) {
    socket.setOption(SocketOption.tcpNoDelay, enabled);
  }

  @override
  Future<Uint8List?> read() async {
    if (readCompleter != null) {
      // Mirrors the contract stated on Connection.read(): only one
      // outstanding read is permitted at a time.
      throw StateError('A read is already pending on this connection.');
    }

    // Drain any data already buffered in the socket before parking.
    // RawSocket only fires RawSocketEvent.read when *new* data arrives
    // from the kernel — if we skipped this, buffered data that arrived
    // before the call would never trigger another event, deadlocking us.
    var buffered = socket.read();

    if (buffered != null) {
      return buffered.isEmpty ? null : buffered;
    }

    // Nothing buffered — park a completer, then arm. Arm after creating
    // the completer so that if the event fires synchronously (on some
    // event-loop implementations) the handler finds a completer in place.
    readCompleter = Completer<Uint8List?>();
    socket.readEventsEnabled = true;
    return readCompleter!.future;
  }

  @override
  Future<int> write(Uint8List data, [int offset = 0, int? count]) async {
    var effectiveCount = count ?? data.length - offset;
    var totalWritten = 0;

    // RawSocket.write() may do a short write if the kernel send buffer is
    // full. We loop until all bytes are sent, suspending on
    // RawSocketEvent.write whenever the buffer needs to drain — exactly
    // as the native tcp_write does internally.
    while (totalWritten < effectiveCount) {
      var written = socket.write(
        data,
        offset + totalWritten,
        effectiveCount - totalWritten,
      );

      totalWritten += written;

      if (totalWritten < effectiveCount) {
        // Send buffer saturated. Park a completer, then arm — same
        // ordering discipline as on the read side.
        writeCompleter = Completer<void>();
        socket.writeEventsEnabled = true;
        await writeCompleter!.future;
      }
    }

    return totalWritten;
  }

  @override
  Future<void> closeWrite() async {
    // Sends FIN in the outgoing direction, mirroring tcp_close_write.
    socket.shutdown(SocketDirection.send);
  }

  @override
  Future<void> close() async {
    // Cancel the subscription first so no further events fire while we
    // are tearing down state.
    await subscription.cancel();

    // Resolve any parked operations cleanly rather than leaving dangling
    // futures. Callers awaiting read() get null (EOF); callers awaiting
    // write() get an error, since the data was never fully sent.
    readCompleter?.complete(null);
    readCompleter = null;
    writeCompleter?.completeError(const ConnectionClosed());
    writeCompleter = null;

    socket.close();
  }

  static Future<RawSocketConnection> connect(
    Object? host,
    int port, {
    Object? sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) async {
    var rawSocket = await RawSocket.connect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
      timeout: timeout,
    );

    return RawSocketConnection(rawSocket);
  }
}
