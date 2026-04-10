import 'dart:async';
import 'dart:io' show InternetAddress, RawServerSocket, RawSocket;

import 'package:sol/sol.dart';
import 'package:sol/src/implementation/raw_socket/connection.dart';

/// Adapts a [RawServerSocket] to the [Listener] interface.
///
/// [RawServerSocket] is a [Stream<RawSocket>] — a single stream of incoming
/// raw sockets. [Listener] exposes two consumption paths: stream-based
/// ([listen]) and pull-based ([accept]). This adapter routes each incoming
/// [RawSocket] to whichever path is active.
///
/// The two paths are mutually exclusive: [accept] throws if [listen] has
/// an active subscriber, and [listen] throws if an [accept] is pending.
///
/// Backpressure flows from the [StreamController] (when [listen] is in use)
/// down to the underlying [RawServerSocket] subscription, so a slow consumer
/// will pause the accept loop at the kernel level.
final class RawServerSocketListener extends Stream<Connection>
    implements Listener {
  RawServerSocketListener(this.server)
    : connections = <RawSocketConnection>{},
      streamActive = false,
      closed = false;

  final RawServerSocket server;

  // All connections accepted through this listener, tracked so we can
  // serve acceptedConnections and close them all on force-close.
  final Set<RawSocketConnection> connections;

  // The single long-lived subscription to server. Created lazily on the
  // first call to accept() or listen(), and shared between both paths.
  StreamSubscription<RawSocket>? subscription;

  // Non-null while a one-shot accept() call is parked waiting for the
  // next incoming socket.
  Completer<Connection>? acceptCompleter;

  // The stream controller used when the caller consumes via listen().
  StreamController<Connection>? controller;

  // True while _controller has an active subscriber. Used to guard
  // against mixing listen() and accept() on the same listener.
  bool streamActive;

  bool closed;

  // ── Listener metadata ───────────────────────────────────────────────────

  @override
  InternetAddress get address => server.address;

  @override
  int get port => server.port;

  @override
  int get acceptedConnections => connections.length;

  // ── Internal helpers ────────────────────────────────────────────────────

  // Wraps an incoming RawSocket, registers it, and wires up the back-
  // reference so the connection can deregister itself on close().
  RawSocketConnection wrapSocket(RawSocket socket) {
    var connection = RawSocketConnection(socket);
    connection.listener = this;
    connections.add(connection);
    return connection;
  }

  // Creates the underlying subscription the first time it is needed.
  // Both accept() and listen() funnel through here so we always have
  // exactly one subscriber on server.
  StreamSubscription<RawSocket> ensureSubscription() {
    return subscription ??= server.listen(
      onData,
      onError: onError,
      onDone: onDone,
    );
  }

  // Routes an incoming socket to whichever path is currently active.
  // The accept() path takes priority: if a completer is parked, resolve
  // it immediately; otherwise hand the connection to the stream controller.
  void onData(RawSocket socket) {
    if (closed) {
      return;
    }

    var completer = acceptCompleter;

    if (completer != null) {
      acceptCompleter = null;
      completer.complete(wrapSocket(socket));
    } else {
      controller?.add(wrapSocket(socket));
    }
  }

  void onError(Object error, StackTrace stack) {
    acceptCompleter?.completeError(error, stack);
    acceptCompleter = null;
    controller?.addError(error, stack);
  }

  void onDone() {
    // The underlying server socket closed — propagate EOF to both paths.
    acceptCompleter?.completeError(const AcceptFailed());
    acceptCompleter = null;
    controller?.close();
  }

  // ── accept() ────────────────────────────────────────────────────────────

  @override
  Future<Connection> accept() {
    if (streamActive) {
      // Matches the guard in _Listener.accept() that checks acceptPort.
      throw StateError(
        'Cannot use accept() while the stream accept loop is active.',
      );
    }

    if (closed) {
      throw StateError('Listener is closed.');
    }

    if (acceptCompleter != null) {
      // One outstanding accept() at a time — mirrors Connection.read().
      throw StateError('An accept() is already pending on this listener.');
    }

    // Ensure the subscription exists before parking the completer, so
    // that incoming connections can flow. Then park — _onData will resolve
    // the completer when the next socket arrives.
    ensureSubscription();

    acceptCompleter = Completer<Connection>();
    return acceptCompleter!.future;
  }

  // ── Stream<Connection> / listen() ───────────────────────────────────────

  @override
  StreamSubscription<Connection> listen(
    void Function(Connection event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (acceptCompleter != null) {
      throw StateError(
        'Cannot start the stream accept loop while accept() is pending.',
      );
    }

    if (closed) {
      throw StateError('Listener is closed.');
    }

    streamActive = true;

    // Ensure the underlying subscription exists before wiring up
    // the controller, so the pause/resume callbacks have a target.
    var subscription = ensureSubscription();

    controller ??= StreamController<Connection>(
      // Thread backpressure: a slow consumer pauses the kernel accept loop.
      onPause: subscription.pause,
      onResume: subscription.resume,
      onCancel: () {
        streamActive = false;
        // Cancel the subscription and null it out so that a subsequent
        // accept() call can start a fresh one if needed.
        subscription.cancel();
        this.subscription = null;
      },
    );

    return controller!.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  // ── close() ─────────────────────────────────────────────────────────────

  @override
  Future<void> close({bool force = false}) async {
    if (closed) {
      return;
    }

    closed = true;

    // Stop the subscription before closing the server socket so that
    // no more _onData callbacks fire while we are tearing down state.
    await subscription?.cancel();
    subscription = null;

    // Resolve any parked accept() with an error — the caller is waiting
    // for a connection that will never arrive.
    acceptCompleter?.completeError(const AcceptFailed());
    acceptCompleter = null;

    // Close the underlying RawServerSocket.
    await server.close();

    if (force) {
      // Close all accepted connections that are still alive.
      await Future.wait<void>(
        connections.map<Future<void>>((connection) => connection.close()),
      );
    }

    controller?.close();
    streamActive = false;
  }
}
