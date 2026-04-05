const std = @import("std");
const RequestPath = @import("mod.zig").request_path.RequestPath;

pub const HttpRequestType = enum { Get, Post, Put, Patch, Delete, Options, Head, Connect, Trace };

pub const HeaderPair = struct {
    key: []const u8,
    value: []const u8,
};

pub const HttpRequestHeader = struct {
    header_bytes: []const u8,
    request_type: HttpRequestType,
    path: RequestPath,
    raw_path: []const u8,
    header_pairs: []const HeaderPair,

    pub fn parse(arena: std.mem.Allocator, header_bytes: []const u8) !HttpRequestHeader {
        const delimiter = "\r\n";
        var iterator = std.mem.tokenizeSequence(u8, header_bytes, delimiter);
        const request_line = try parse_request_type_and_path(arena, &iterator);
        const header_pairs = try parse_header_pairs(arena, &iterator);

        const self = HttpRequestHeader{
            .header_bytes = header_bytes,
            .request_type = request_line.request_type,
            .path = request_line.request_path,
            .raw_path = request_line.raw_path,
            .header_pairs = header_pairs,
        };

        return self;
    }

    pub fn getHeader(self: *const HttpRequestHeader, key: []const u8) ?[]const u8 {
        for (self.header_pairs) |pair| {
            if (std.mem.eql(u8, pair.key, key)) {
                return pair.value;
            }
        }

        return null;
    }
};

fn parse_header_pairs(arena: std.mem.Allocator, iterator: *std.mem.TokenIterator(u8, .sequence)) ![]const HeaderPair {
    var header_pairs = std.ArrayList(HeaderPair).empty;
    while (iterator.next()) |pair_line| {
        if (std.mem.trim(u8, pair_line, &std.ascii.whitespace).len == 0) {
            continue;
        }
        const delim = ": ";
        if (std.mem.find(u8, pair_line, delim)) |pos| {
            const key = pair_line[0..pos];
            const value = pair_line[pos + delim.len ..];
            const header_pair = HeaderPair{
                .key = key,
                .value = value,
            };
            try header_pairs.append(arena, header_pair);
        } else {
            return error.InvalidHeaderPair;
        }
    }

    return try header_pairs.toOwnedSlice(arena);
}

const RequestLine = struct {
    request_type: HttpRequestType,
    request_path: RequestPath,
    raw_path: []const u8,
};
fn parse_request_type_and_path(arena: std.mem.Allocator, iterator: *std.mem.TokenIterator(u8, .sequence)) !RequestLine {
    const first_line = iterator.next();
    if (first_line == null) {
        return error.HeaderEmpty;
    }
    const delimiter = ' ';
    var first_line_iter = std.mem.tokenizeScalar(u8, first_line.?, delimiter);
    const type_string = first_line_iter.next();
    if (type_string == null) {
        return error.InvalidRequestLine;
    }
    const request_type = try parse_request_type(type_string.?);

    const path_string = first_line_iter.next();
    if (path_string == null) {
        return error.InvalidRequestLine;
    }
    const path = try RequestPath.parse(arena, path_string.?);

    const http_version = first_line_iter.next();
    if (http_version == null) {
        return error.InvalidRequestLine;
    }

    return .{ .request_type = request_type, .request_path = path, .raw_path = path_string.? };
}

fn parse_request_type(string: []const u8) !HttpRequestType {
    if (std.mem.eql(u8, string, "GET")) return .Get;
    if (std.mem.eql(u8, string, "PUT")) return .Put;
    if (std.mem.eql(u8, string, "POST")) return .Post;
    if (std.mem.eql(u8, string, "PATCH")) return .Patch;
    if (std.mem.eql(u8, string, "DELETE")) return .Delete;
    if (std.mem.eql(u8, string, "OPTIONS")) return .Options;
    if (std.mem.eql(u8, string, "HEAD")) return .Head;
    if (std.mem.eql(u8, string, "CONNECT")) return .Connect;
    if (std.mem.eql(u8, string, "TRACE")) return .Trace;

    return error.InvalidRequestType;
}
