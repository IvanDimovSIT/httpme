const std = @import("std");
const Io = std.Io;

const tcp = @import("../tcp.zig");
const errors = @import("../errors.zig");
const mod = @import("mod.zig");
const HttpRequestHeader = mod.http_request_header.HttpRequestHeader;
const HttpRequest = mod.http_request.HttpRequest;
const endpoint_handler_mod = mod.endpoint_handler;
const EndpointPair = endpoint_handler_mod.EndpointPair;

pub const HttpConfig = struct { address: []const u8 = "127.0.0.1", port: u16 = 8080, endpoint_handlers: []const EndpointPair };

const HttpHandlerState = struct { endpoint_handlers: []const EndpointPair };

pub fn startHttpServer(io: Io, gpa: std.mem.Allocator, config: HttpConfig) !void {
    var handler_state = HttpHandlerState{ .endpoint_handlers = config.endpoint_handlers };
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
    const header_bytes = try readHeader(context.arena, context.reader);
    const header = try HttpRequestHeader.parse(context.arena, header_bytes);
    const endpoint_handler = try endpoint_handler_mod.findHandler(context.arena, state.endpoint_handlers, &header.path);
    if (endpoint_handler == null) {
        // TODO: return valid response
        try context.writer.print("Endpoint not found", .{});
        return;
    }

    const content_length_str = if (header.request_type == .Get) null else header.getHeader("Content-Length");
    const content_length = if (content_length_str != null) try std.fmt.parseInt(usize, content_length_str.?, 10) else 0;
    const body = try context.reader.readAlloc(context.arena, content_length);
    var request = HttpRequest{
        .io = context.io,
        .gpa = context.gpa,
        .arena = context.arena,
        .header = header,
        .path_variables = endpoint_handler.?.path_variables,
        .body = body,
    };
    const response = try endpoint_handler.?.handler(&request);

    std.debug.print("params {any}", .{request.header.path.request_params});
    std.debug.print("handleTcp input: {} {} , content length:{d} header:\n{s}\nbody:\n{s}\n", .{ header.request_type, header.path, content_length, header.header_bytes, body });
    try context.writer.print("Received,\n{s}", .{response.body});
}
