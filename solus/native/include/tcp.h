#ifndef TCP_SOCKET_H
#define TCP_SOCKET_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Symbol export.
 *
 * On Windows, shared-library symbols must be exported explicitly for Dart FFI
 * to resolve them from the DLL.
 */
#ifdef _WIN32
    #define TCP_EXPORT __declspec(dllexport)
#else
    #define TCP_EXPORT
#endif

/* =============================================================================
 * Overview
 * =============================================================================
 *
 * Public C API for asynchronous TCP sockets intended for use from Dart FFI.
 *
 * Current backend:
 *   - Windows IOCP implementation
 *   - background worker threads (one or more shards)
 *   - async connect / accept / read / write
 *   - synchronous property getters/setters
 *
 * This header describes the CURRENT behavior of the implementation.
 */

/* =============================================================================
 * Initialization
 * =============================================================================
 */

/**
 * Initialize the TCP library and bind it to the Dart API.
 *
 * Must be called before any other function.
 * Idempotent: repeated successful calls return 0.
 *
 * Returns:
 *   0 on success
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_init(void* dart_api_dl);

/**
 * Stop worker threads and release backend resources.
 *
 * The current implementation stops the IOCP worker threads and tears down the
 * backend state. Callers should close live handles before destroy.
 */
TCP_EXPORT void tcp_destroy(void);

/* =============================================================================
 * Message Protocol
 * =============================================================================
 *
 * Operations that complete asynchronously post results to Dart ports.
 *
 * Triplet success/error forms:
 *
 *   connect/listen success:
 *     [request_id, handle, 0]
 *
 *   accept success:
 *     [request_id, connection_handle, 0]
 *
 *   write success:
 *     [request_id, total_bytes_written, null]
 *
 *   read success:
 *     [request_id, bytes_read, external_uint8_data]
 *
 *   connect/listen/accept/read/write error:
 *     [request_id, negative_error_code, null]
 *
 * Accept loop form:
 *
 *   tcp_accept_loop posts a bare int64 to its dedicated port:
 *     > 0  => accepted connection handle
 *     < 0  => negative TCP_ERR_* code
 *
 * Close operations:
 *
 *   tcp_close_write, tcp_close, and tcp_listener_close do not post completion
 *   messages in the current implementation.
 */

/* =============================================================================
 * Connection Operations
 * =============================================================================
 *
 * Handle-creating operations (tcp_connect, tcp_listen) take a send_port.
 * Read/write/accept-once completions are routed through the send_port stored in
 * the owning handle.
 *
 * In the current implementation, close operations do not post completion
 * callbacks even though they are queued asynchronously.
 */

/**
 * Start an asynchronous outbound TCP connection.
 *
 * Arguments:
 *   send_port      Dart native port used for completion delivery
 *   request_id     non-zero request identifier
 *   addr           pointer to remote address bytes
 *   addr_len       4 for IPv4, 16 for IPv6
 *   port           remote port
 *   source_addr    local bind address bytes, or NULL / length 0 for any
 *   source_addr_len length of source_addr
 *   source_port    local port, or 0 for any
 *
 * Completion:
 *   success -> [request_id, connection_handle, 0]
 *   error   -> [request_id, negative_error_code, null]
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_connect(
    int64_t send_port,
    int64_t request_id,
    const uint8_t* addr,
    int64_t addr_len,
    int64_t port,
    const uint8_t* source_addr,
    int64_t source_addr_len,
    int64_t source_port
);

/**
 * Start an asynchronous read from a connection.
 *
 * Only valid for connection handles.
 * request_id must be non-zero.
 *
 * Completion:
 *   success -> [request_id, bytes_read, external_uint8_data]
 *   EOF/error -> [request_id, negative_error_code, null]
 *
 * Notes:
 *   - peer close is reported as TCP_ERR_CLOSED
 *   - data ownership is transferred to Dart via external typed data finalizer
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_read(int64_t request_id, int64_t handle);

/**
 * Start an asynchronous write on a connection.
 *
 * Only valid for connection handles.
 * request_id must be non-zero.
 *
 * The implementation copies exactly `count` bytes from `data + offset`
 * immediately. The caller must ensure that this range is readable.
 *
 * Completion:
 *   success -> [request_id, total_bytes_written, null]
 *   error   -> [request_id, negative_error_code, null]
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_write(
    int64_t request_id,
    int64_t handle,
    const uint8_t* data,
    int64_t offset,
    int64_t count
);

/**
 * Queue shutdown of the write side of a connection.
 *
 * Only valid for connection handles.
 *
 * Current behavior:
 *   - request_id is accepted but ignored
 *   - no completion message is posted back to Dart
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_close_write(int64_t request_id, int64_t handle);

/**
 * Queue close of a handle.
 *
 * Current behavior:
 *   - accepts either a connection handle or a listener handle
 *   - request_id is accepted but ignored
 *   - no completion message is posted back to Dart
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_close(int64_t request_id, int64_t handle);

/* =============================================================================
 * Listener Operations
 * =============================================================================
 */

/**
 * Create a listening socket asynchronously.
 *
 * Arguments:
 *   send_port   Dart native port used for completion delivery
 *   request_id  non-zero request identifier
 *   addr        local bind address bytes
 *   addr_len    4 for IPv4, 16 for IPv6
 *   port        local port, 0 allowed
 *   v6_only     used only for IPv6 listeners
 *   backlog     <= 0 means use backend default
 *   shared      current Windows backend enables SO_REUSEADDR only
 *
 * Completion:
 *   success -> [request_id, listener_handle, 0]
 *   error   -> [request_id, negative_error_code, null]
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_listen(
    int64_t send_port,
    int64_t request_id,
    const uint8_t* addr,
    int64_t addr_len,
    int64_t port,
    bool v6_only,
    int64_t backlog,
    bool shared
);

/**
 * Accept one incoming connection asynchronously.
 *
 * Only valid for listener handles.
 * request_id must be non-zero.
 *
 * The accepted connection inherits the listener's stored send_port.
 *
 * Completion:
 *   success -> [request_id, connection_handle, 0]
 *   error   -> [request_id, negative_error_code, null]
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_accept(int64_t request_id, int64_t listener_handle);

/**
 * Start a continuous accept loop on a listener.
 *
 * Each accepted connection is posted to the dedicated port as a bare int64:
 *   > 0 => connection handle
 *   < 0 => negative TCP_ERR_* code
 *
 * The loop stops when the listener is closed or when posting to the Dart port
 * fails.
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_accept_loop(
    int64_t send_port,
    int64_t listener_handle
);

/**
 * Queue close of a listener.
 *
 * Current behavior:
 *   - request_id is accepted but ignored
 *   - force is accepted but currently ignored
 *   - no completion message is posted back to Dart
 *
 * Returns:
 *   0 on successful queue
 *   negative TCP_ERR_* code on immediate failure
 */
TCP_EXPORT int64_t tcp_listener_close(
    int64_t request_id,
    int64_t listener_handle,
    bool force
);

/* =============================================================================
 * Synchronous Property Access
 * =============================================================================
 *
 * These functions access socket state synchronously and may take internal locks.
 * Do not bind them as Dart leaf calls.
 */

/**
 * Get the local address of a connection or listener.
 *
 * out_addr must point to a buffer large enough for 16 bytes.
 *
 * Returns:
 *   4 for IPv4
 *   16 for IPv6
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_get_local_address(int64_t handle, uint8_t* out_addr);

/**
 * Get the local port of a connection or listener.
 *
 * Returns:
 *   positive port number
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_get_local_port(int64_t handle);

/**
 * Get the remote address of a connection.
 *
 * Only valid for connection handles.
 * out_addr must point to a buffer large enough for 16 bytes.
 *
 * Returns:
 *   4 for IPv4
 *   16 for IPv6
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_get_remote_address(int64_t handle, uint8_t* out_addr);

/**
 * Get the remote port of a connection.
 *
 * Only valid for connection handles.
 *
 * Returns:
 *   positive port number
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_get_remote_port(int64_t handle);

/**
 * Get SO_KEEPALIVE state for a connection.
 *
 * Returns:
 *   1 if enabled
 *   0 if disabled
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_get_keep_alive(int64_t handle);

/**
 * Set SO_KEEPALIVE state for a connection.
 *
 * Returns:
 *   0 on success
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_set_keep_alive(int64_t handle, bool enabled);

/**
 * Get TCP_NODELAY state for a connection.
 *
 * Returns:
 *   1 if enabled
 *   0 if disabled
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_get_no_delay(int64_t handle);

/**
 * Set TCP_NODELAY state for a connection.
 *
 * Returns:
 *   0 on success
 *   negative TCP_ERR_* code on failure
 */
TCP_EXPORT int64_t tcp_set_no_delay(int64_t handle, bool enabled);

/* =============================================================================
 * Error Codes
 * =============================================================================
 */

#define TCP_ERR_INVALID_HANDLE      -1
#define TCP_ERR_INVALID_ADDRESS     -2
#define TCP_ERR_CONNECT_FAILED      -3
#define TCP_ERR_BIND_FAILED         -4
#define TCP_ERR_LISTEN_FAILED       -5
#define TCP_ERR_ACCEPT_FAILED       -6
#define TCP_ERR_READ_FAILED         -7
#define TCP_ERR_WRITE_FAILED        -8
#define TCP_ERR_CLOSED              -9
#define TCP_ERR_SOCKET_OPTION       -10
#define TCP_ERR_NOT_INITIALIZED     -11
#define TCP_ERR_OUT_OF_MEMORY       -12
#define TCP_ERR_INVALID_ARGUMENT    -13

#ifdef __cplusplus
}
#endif

#endif /* TCP_SOCKET_H */
