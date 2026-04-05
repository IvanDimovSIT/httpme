const std = @import("std");
const Io = std.Io;

const tcp = @import("../tcp.zig");
const errors = @import("../errors.zig");
const mod = @import("mod.zig");
const HttpRequestHeader = mod.http_request_header.HttpRequestHeader;
const HttpRequest = mod.http_request.HttpRequest;
const endpoint_handler_mod = mod.endpoint_handler;
const EndpointPair = endpoint_handler_mod.EndpointPair;
const PathHandlerPair = endpoint_handler_mod.PathHandlerPair;
const EndpointHandler = endpoint_handler_mod.EndpointHandler;
const HttpResponse = mod.http_response.HttpResponse;

pub const HttpConfig = struct { address: []const u8 = "127.0.0.1", port: u16 = 8080, endpoint_handlers: []const PathHandlerPair };

const HttpHandlerState = struct { endpoint_handlers: []const EndpointPair };

const not_found_response = HttpResponse{
    .response_type = .NotFound,
    .body = "{\"error\":\"Resource not found\"}",
};

pub fn startHttpServer(gpa: std.mem.Allocator, config: HttpConfig) !void {
    const handler_pairs = try EndpointPair.allocPairs(gpa, config.endpoint_handlers);
    defer EndpointPair.dealoc(gpa, handler_pairs);

    var handler_state = HttpHandlerState{ .endpoint_handlers = handler_pairs };
    const http_handler = tcp.TcpHandler(HttpHandlerState){
        .state = &handler_state,
        .handler = handleTcp,
    };

    const address = try Io.net.IpAddress.parse(config.address, config.port);
    std.log.info("Starting server on {s}:{d}", .{ config.address, config.port });

    tcp.handleTcp(HttpHandlerState, gpa, address, &http_handler) catch |err| {
        std.log.err("{}", .{err});
    };
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

fn handleRequest(endpoint_handler: EndpointHandler, request: *HttpRequest) HttpResponse {
    return endpoint_handler(request) catch |err| {
        std.log.err("{}", .{err});
        return HttpResponse{
            .response_type = .InternalServerError,
            .body = "{\"error\": \"An unexpected error occurred\"}",
        };
    };
}

fn logRequest(request_header: *const HttpRequestHeader, response: *const HttpResponse) void {
    std.log.info("request: {} {s}; response: {}", .{ request_header.request_type, request_header.raw_path, response.response_type });
}

fn handleTcp(state: *HttpHandlerState, context: tcp.TcpContext) !void {
    const header_bytes = try readHeader(context.arena, context.reader);
    const header = try HttpRequestHeader.parse(context.arena, header_bytes);
    const endpoint_handler = try endpoint_handler_mod.findHandler(context.arena, state.endpoint_handlers, &header.path);
    if (endpoint_handler == null) {
        try not_found_response.writeResponseString(context.writer);
        logRequest(&header, &not_found_response);
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
    const response = handleRequest(endpoint_handler.?.handler, &request);

    try response.writeResponseString(context.writer);
    logRequest(&header, &response);
}
