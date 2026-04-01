const std = @import("std");

pub const RequestParam = struct {
    key: []const u8,
    value: []const u8,
};

pub const RequestPath = struct {
    path_parts: [][]const u8,
    request_params: []const RequestParam,

    pub fn parse(arena: std.mem.Allocator, request_path_string: []const u8) !RequestPath {
        const split_request = splitRequestPath(request_path_string);
        const path_parts = try parsePathParts(arena, split_request.path_part);
        const request_params = try parseRequestParams(arena, split_request.param_part);

        return .{
            .path_parts = path_parts,
            .request_params = request_params,
        };
    }
};

fn parseRequestParams(arena: std.mem.Allocator, params_string: []const u8) ![]const RequestParam {
    var request_params = std.ArrayList(RequestParam).empty;
    var iterator = std.mem.tokenizeScalar(u8, params_string, '&');
    while (iterator.next()) |params_pair| {
        const delim = "=";
        const index = std.mem.find(u8, params_pair, delim);
        if (index == null) {
            return error.InvalidRequestParam;
        }
        const key = params_pair[0..index.?];
        const value = params_pair[index.? + 1 ..];
        try request_params.append(arena, .{ .key = key, .value = value });
    }

    return try request_params.toOwnedSlice(arena);
}

fn parsePathParts(arena: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var path_parts = std.ArrayList([]const u8).empty;
    var iterator = std.mem.tokenizeScalar(u8, path, '/');
    while (iterator.next()) |path_part| {
        try path_parts.append(arena, path_part);
    }

    return try path_parts.toOwnedSlice(arena);
}

const SplitRequest = struct {
    path_part: []const u8,
    param_part: []const u8,
};
fn splitRequestPath(request_path_string: []const u8) SplitRequest {
    const param_delim = "?";
    if (std.mem.find(u8, request_path_string, param_delim)) |pos| {
        const path_part = request_path_string[0..pos];
        const param_part = request_path_string[pos + param_delim.len ..];
        return SplitRequest{
            .path_part = std.mem.trim(u8, path_part, &std.ascii.whitespace),
            .param_part = std.mem.trim(u8, param_part, &std.ascii.whitespace),
        };
    } else {
        return SplitRequest{
            .path_part = std.mem.trim(u8, request_path_string, &std.ascii.whitespace),
            .param_part = &.{},
        };
    }
}
