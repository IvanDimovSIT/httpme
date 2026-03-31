const std = @import("std");
const Io = std.Io;

pub const tcp = @import("tcp.zig");
pub const errors = @import("errors.zig");

pub const HttpConfig = struct {
    address: []const u8 = "127.0.0.1",
    port: u16 = 8080,
};

pub fn startHttpServer(io: Io, gpa: std.mem.Allocator, config: HttpConfig) !void {
    const address = try Io.net.IpAddress.parse(config.address, config.port);
    var server = try Io.net.IpAddress.listen(address, io, .{});
    defer server.deinit(io);
    std.debug.print("Starting server on {s}:{d}\n", .{ config.address, config.port });
    while (true) {
        tcp.handleTcp(io, gpa, &server, handleTcp) catch |err| {
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

fn handleTcp(context: tcp.TcpContext) !void {
    const header = try readHeader(context.arena, context.reader);
    std.debug.print("Read header:\n{s}\n", .{header});
    try context.writer.print("Received", .{});
}
