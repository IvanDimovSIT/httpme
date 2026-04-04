const std = @import("std");
const Io = std.Io;
const http_request_header = @import("http_request_header.zig");
const HttpRequestHeader = http_request_header.HttpRequestHeader;

pub const HttpRequest = struct {
    io: Io,
    gpa: std.mem.Allocator,
    arena: std.mem.Allocator,
    header: HttpRequestHeader,
    path_variables: [][]const u8,
    body: []const u8,

    pub fn getRequestParam(self: *const HttpRequest, param_key: []const u8) ?[]const u8 {
        for (self.header.path.request_params) |request_param| {
            if (std.mem.eql(u8, request_param.key, param_key)) {
                return request_param.value;
            }
        }

        return null;
    }
};
