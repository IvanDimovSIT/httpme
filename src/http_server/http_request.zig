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
};
