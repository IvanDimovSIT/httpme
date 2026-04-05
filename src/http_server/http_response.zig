const std = @import("std");

pub const ResponseType = enum(u16) {
    Ok = 200,
    Created = 201,
    NoContent = 204,
    BadRequest = 400,
    Unauthorized = 401,
    Forbidden = 403,
    NotFound = 404,
    InternalServerError = 500,

    pub fn getDescription(self: ResponseType) []const u8 {
        return switch (self) {
            .Ok => "200 OK",
            .Created => "201 Created",
            .NoContent => "204 No Content",
            .BadRequest => "400 Bad Request",
            .Unauthorized => "401 Unauthorized",
            .Forbidden => "403 Forbidden",
            .NotFound => "404 Not Found",
            .InternalServerError => "500 Internal Server Error",
        };
    }
};

pub const HttpResponse = struct {
    response_type: ResponseType = .Ok,
    body: []const u8 = "",
    content_type: []const u8 = "application/json",

    pub fn writeResponseString(self: HttpResponse, writer: *std.Io.Writer) !void {
        const args = .{ self.response_type.getDescription(), self.content_type, self.body.len, self.body };
        try writer.print("HTTP/1.1 {s}\r\nContent-Type: {s}\r\nConnection: close\r\nContent-Length: {d}\r\n\r\n{s}", args);
        try writer.flush();
    }
};
