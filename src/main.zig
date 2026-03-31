const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    try httpme.http.startHttpServer(io, gpa, .{});
}
