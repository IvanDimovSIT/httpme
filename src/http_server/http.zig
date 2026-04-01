const std = @import("std");
const Io = std.Io;

pub const tcp = @import("../tcp.zig");
pub const errors = @import("../errors.zig");
pub const http_request_header = @import("http_request_header.zig");

pub const HttpConfig = struct {
    address: []const u8 = "127.0.0.1",
    port: u16 = 8080,
};

const HttpHandlerState = struct {};

pub fn startHttpServer(io: Io, gpa: std.mem.Allocator, config: HttpConfig) !void {
    var handler_state = HttpHandlerState{};
    const http_handler = tcp.TcpHandler(HttpHandlerState){
        .state = &handler_state,
        .handler = handleTcp,
    };
    const address = try Io.net.IpAddress.parse(config.address, config.port);
    var server = try Io.net.IpAddress.listen(address, io, .{});
    defer server.deinit(io);
    std.debug.print("Starting server on {s}:{d}\n", .{ config.address, config.port });
    while (true) {
        tcp.handleTcp(HttpHandlerState, io, gpa, &server, &http_handler) catch |err| {
            std.debug.print("ERROR: {}\n", .{err});
        };
    }
}

fn readHeader(arena: std.mem.Allocator, reader: *std.Io.Reader) ![]u8 {
    const max_header_size = 1024 * 1024;
    var array: std.ArrayList(u8) = .empty;
    while (!std.mem.endsWith(u8, array.items, "\r\n\r\n")) {
        const read_byte = try reader.takeByte();
        try array.append(arena, read_byte);
        if (array.items.len > max_header_size) {
            return error.HeaderTooLarge;
        }
    }

    return array.toOwnedSlice(arena);
}

fn handleTcp(state: *HttpHandlerState, context: tcp.TcpContext) !void {
    _ = state;
    const header_bytes = try readHeader(context.arena, context.reader);
    const header = try http_request_header.HttpRequestHeader.init(context.arena, header_bytes);
    const content_length_str = if (header.request_type == .Get) null else header.getHeader("Content-Length");
    const content_length = if (content_length_str != null) try std.fmt.parseInt(usize, content_length_str.?, 10) else 0;
    const body = try context.reader.readAlloc(context.arena, content_length);

    std.debug.print("handleTcp input: {} {s} , content length:{d} header:\n{s}\nbody:\n{s}\n", .{ header.request_type, header.path, content_length, header.header_bytes, body });
    try context.writer.print("Received", .{});
}
