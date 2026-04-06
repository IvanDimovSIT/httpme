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

pub fn HttpConfig(AppState: type) type {
    return struct { address: []const u8 = "127.0.0.1", port: u16 = 8080, endpoint_handlers: []const PathHandlerPair(AppState), app_state: *AppState };
}

fn HttpHandlerState(AppState: type) type {
    return struct { endpoint_handlers: []const EndpointPair(AppState), app_state: *AppState };
}

const not_found_response = HttpResponse{
    .response_type = .NotFound,
    .body = "{\"error\":\"Resource not found\"}",
};
const internal_server_error_response = HttpResponse{
    .response_type = .InternalServerError,
    .body = "{\"error\": \"An unexpected error occurred\"}",
};

pub fn startHttpServer(AppState: type, gpa: std.mem.Allocator, config: HttpConfig(AppState)) !void {
    const handler_pairs = try EndpointPair(AppState).allocPairs(gpa, config.endpoint_handlers);
    defer EndpointPair(AppState).dealoc(gpa, handler_pairs);

    var handler_state = HttpHandlerState(AppState){ .endpoint_handlers = handler_pairs, .app_state = config.app_state };
    const http_handler = tcp.TcpHandler(HttpHandlerState(AppState)){
        .state = &handler_state,
        .handler = handleTcpFn(AppState),
    };

    const address = try Io.net.IpAddress.parse(config.address, config.port);
    std.log.info("Starting server on {s}:{d}", .{ config.address, config.port });

    tcp.handleTcp(HttpHandlerState(AppState), gpa, address, &http_handler) catch |err| {
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

fn handleRequest(AppState: type, endpoint_handler: EndpointHandler(AppState), request: *HttpRequest(AppState)) HttpResponse {
    return endpoint_handler(request) catch |err| {
        std.log.err("{}", .{err});
        return internal_server_error_response;
    };
}

fn logRequest(request_header: *const HttpRequestHeader, response: *const HttpResponse) void {
    std.log.info("request: {} {s}; response: {}", .{ request_header.request_type, request_header.raw_path, response.response_type });
}

/// creates the tcp handler polymorphic function
fn handleTcpFn(comptime AppState: type) fn (*HttpHandlerState(AppState), tcp.TcpContext) anyerror!void {
    return struct {
        fn handler(state: *HttpHandlerState(AppState), context: tcp.TcpContext) !void {
            return handleTcp(AppState, state, context);
        }
    }.handler;
}

fn handleTcp(AppState: type, state: *HttpHandlerState(AppState), context: tcp.TcpContext) !void {
    errdefer internal_server_error_response.writeResponseString(context.writer) catch |err| {
        std.log.err("handleTcp error {}", .{err});
    };
    const header_bytes = try readHeader(context.arena, context.reader);
    const header = try HttpRequestHeader.parse(context.arena, header_bytes);
    const endpoint_handler = try endpoint_handler_mod.findHandler(AppState, context.arena, state.endpoint_handlers, &header.path);
    if (endpoint_handler == null) {
        try not_found_response.writeResponseString(context.writer);
        logRequest(&header, &not_found_response);
        return;
    }

    const content_length_str = if (header.request_type == .Get) null else header.getHeader("Content-Length");
    const content_length = if (content_length_str != null) try std.fmt.parseInt(usize, content_length_str.?, 10) else 0;
    const body = try context.reader.readAlloc(context.arena, content_length);
    var request = HttpRequest(AppState){ .io = context.io, .gpa = context.gpa, .arena = context.arena, .header = header, .path_variables = endpoint_handler.?.path_variables, .body = body, .app_state = state.app_state };
    const response = handleRequest(AppState, endpoint_handler.?.handler, &request);

    try response.writeResponseString(context.writer);
    logRequest(&header, &response);
}
