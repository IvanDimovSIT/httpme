const std = @import("std");
const Io = std.Io;

pub const TcpContext = struct {
    io: Io,
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    reader: *Io.Reader,
    writer: *Io.Writer,
};

pub fn TcpHandler(HandlerState: type) type {
    return struct {
        handler: *const fn (*HandlerState, TcpContext) anyerror!void,
        state: *HandlerState,

        fn handleRequest(self: @This(), context: TcpContext) anyerror!void {
            try self.handler(self.state, context);
        }
    };
}

pub fn handleTcp(HandlerState: type, io: Io, gpa: std.mem.Allocator, address: Io.net.IpAddress, handler: *const TcpHandler(HandlerState)) !void {
    var server = try Io.net.IpAddress.listen(&address, io, .{});
    defer server.deinit(io);
    const handler_fn = handleTcpConnectionErrorHandled(HandlerState);

    while (true) {
        const server_stream = server.accept(io) catch |err| {
            std.log.err("{}", .{err});
            continue;
        };
        _ = io.async(handler_fn, .{ io, gpa, server_stream, handler });
    }
}

fn handleTcpConnectionErrorHandled(HandlerState: type) fn (
    Io,
    std.mem.Allocator,
    Io.net.Stream,
    *const TcpHandler(HandlerState),
) void {
    return struct {
        fn f(
            io: Io,
            gpa: std.mem.Allocator,
            stream: Io.net.Stream,
            handler: *const TcpHandler(HandlerState),
        ) void {
            var stream_mut = stream;
            handleTcpConnection(HandlerState, io, gpa, &stream_mut, handler) catch |err| {
                std.log.err("TCP error {}", .{err});
            };
        }
    }.f;
}

/// handles single TCP request, consumes the stream
fn handleTcpConnection(HandlerState: type, io: Io, gpa: std.mem.Allocator, stream: *Io.net.Stream, handler: *const TcpHandler(HandlerState)) !void {
    defer stream.close(io);
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var server_reader_buff: [4 * 1024]u8 = undefined;
    var server_writer_buff: [4 * 1024]u8 = undefined;
    var reader_struct = stream.reader(io, &server_reader_buff);
    var writer_struct = stream.writer(io, &server_writer_buff);
    const reader = &reader_struct.interface;
    const writer = &writer_struct.interface;

    const tcp_context = TcpContext{ .io = io, .gpa = gpa, .arena = arena, .reader = reader, .writer = writer };
    try handler.handleRequest(tcp_context);
    try writer.flush();
}
