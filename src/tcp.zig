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

/// handles single TCP request
pub fn handleTcp(HandlerState: type, io: Io, gpa: std.mem.Allocator, server: *Io.net.Server, handler: *const TcpHandler(HandlerState)) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var server_stream = try server.accept(io);
    defer server_stream.close(io);

    var server_reader_buff: [4 * 1024]u8 = undefined;
    var server_writer_buff: [4 * 1024]u8 = undefined;
    var reader_struct = server_stream.reader(io, &server_reader_buff);
    var writer_struct = server_stream.writer(io, &server_writer_buff);
    const reader = &reader_struct.interface;
    const writer = &writer_struct.interface;

    const tcp_context = TcpContext{ .io = io, .gpa = gpa, .arena = arena, .reader = reader, .writer = writer };
    try handler.handleRequest(tcp_context);
    try writer.flush();
}
