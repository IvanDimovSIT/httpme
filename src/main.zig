const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    try http.startHttpServer(io, gpa, .{});
}
