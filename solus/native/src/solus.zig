const std = @import("std");

const net = std.net;

const Address = net.Address;

const dart = @cImport(
    @cInclude("dart_api_dl.h"),
);

fn postMessage(send_port: i64, request_id: i64, result: i64) void {
    if (dart.Dart_PostCObject_DL) |PostMessage| {
        var array: [3]dart.Dart_CObject = undefined;

        array[0] = dart.Dart_CObject{
            .type = dart.Dart_CObject_kInt64,
            .value = .{ .as_int64 = request_id },
        };

        array[1] = dart.Dart_CObject{
            .type = dart.Dart_CObject_kInt64,
            .value = .{ .as_int64 = result },
        };

        array[2] = dart.Dart_CObject{
            .type = dart.Dart_CObject_kNull,
        };

        std.debug.assert(PostMessage(send_port, @constCast(&dart.Dart_CObject{
            .type = dart.Dart_CObject_kArray,
            .value = .{ .as_array = array },
        })));
    }
}

export fn tcp_init(api_dl_data: *anyopaque) isize {
    return dart.Dart_InitializeApiDL(api_dl_data);
}

const Listener = struct {
    send_port: i64,
    server: std.net.Server,
};

export fn tcp_listen(
    send_port: i64,
    request_id: i64,
    addr: [*]const u8,
    addr_len: i64,
    port: i64,
    v6_only: bool,
    backlog: i64,
    shared: bool,
) i64 {
    _ = v6_only;

    var address: Address = undefined;

    if (addr_len == 4) {
        address = Address.initIp4(addr[0..4].*, @intCast(port));
    } else if (addr_len == 16) {
        address = Address.initIp6(addr[0..16].*, @intCast(port), 0, 0);
    } else {
        return -1;
    }

    const server = address.listen(.{
        .kernel_backlog = @intCast(backlog),
        .reuse_address = shared,
    }) catch |err| {
        return @intFromError(err);
    };

    postMessage(send_port, request_id, @intCast(@intFromPtr(&Listener{
        .send_port = send_port,
        .server = server,
    })));

    return 0;
}

export fn tcp_listen_close(
    request_id: i64,
    handle: usize,
    force: bool,
) i64 {
    _ = force;

    var listener: *Listener = @ptrFromInt(@as(usize, handle));
    const send_port = listener.send_port;
    listener.server.deinit();
    listener = undefined;
    postMessage(send_port, request_id, 0);
    return 0;
}
