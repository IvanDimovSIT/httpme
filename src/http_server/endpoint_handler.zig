const std = @import("std");
const mod = @import("mod.zig");
const RequestPath = mod.request_path.RequestPath;
const HttpRequest = mod.http_request.HttpRequest;
const HttpResponse = mod.http_response.HttpResponse;

pub fn EndpointHandler(AppState: type) type {
    return *const fn (*HttpRequest(AppState)) anyerror!HttpResponse;
}

/// use * for path variables
pub fn PathHandlerPair(AppState: type) type {
    return struct { path: []const u8, handler: EndpointHandler(AppState) };
}

pub fn EndpointPair(AppState: type) type {
    return struct {
        path_parts: [][]const u8,
        handler: EndpointHandler(AppState),

        pub fn allocPairs(gpa: std.mem.Allocator, paths: []const PathHandlerPair(AppState)) ![]const EndpointPair(AppState) {
            var endpoints = std.ArrayList(EndpointPair(AppState)).empty;
            errdefer endpoints.deinit(gpa);
            for (paths) |path| {
                var iter = std.mem.tokenizeScalar(u8, path.path, '/');
                var path_part = std.ArrayList([]const u8).empty;
                errdefer path_part.deinit(gpa);
                while (iter.next()) |value| {
                    try path_part.append(gpa, value);
                }
                const pair = EndpointPair(AppState){ .path_parts = try path_part.toOwnedSlice(gpa), .handler = path.handler };
                try endpoints.append(gpa, pair);
            }

            return try endpoints.toOwnedSlice(gpa);
        }

        pub fn dealoc(gpa: std.mem.Allocator, pairs: []const EndpointPair(AppState)) void {
            for (pairs) |pair| {
                gpa.free(pair.path_parts);
            }
            gpa.free(pairs);
        }
    };
}

pub fn ResolvedPath(AppState: type) type {
    return struct { handler: EndpointHandler(AppState), path_variables: [][]const u8 };
}

pub fn findHandler(AppState: type, arena: std.mem.Allocator, handlers: []const EndpointPair(AppState), request_path: *const RequestPath) !?ResolvedPath(AppState) {
    outer: for (handlers) |handler| {
        if (request_path.path_parts.len != handler.path_parts.len) {
            continue;
        }
        var path_variables = std.ArrayList([]const u8).empty;
        for (request_path.path_parts, handler.path_parts) |req_part, handler_part| {
            if (std.mem.eql(u8, handler_part, "*")) {
                try path_variables.append(arena, req_part);
            } else if (!std.mem.eql(u8, handler_part, req_part)) {
                path_variables.deinit(arena);
                continue :outer;
            }
        }
        return ResolvedPath(AppState){ .handler = handler.handler, .path_variables = try path_variables.toOwnedSlice(arena) };
    }

    return null;
}
