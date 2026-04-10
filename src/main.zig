const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;
const app = httpme.app;
const AppState = app.app_state.AppState;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var app_state = try allocAppState(io, gpa);
    defer app_state.deinit();

    try http.startHttpServer(AppState, gpa, .{ .endpoint_handlers = &app.endpoints.paths, .app_state = &app_state });
}

fn allocAppState(io: Io, gpa: std.mem.Allocator) !AppState {
    const loaded_app_state = app.persistence.loadAppState(io, gpa) catch null;
    if (loaded_app_state) |app_state| {
        std.log.info("Loaded saved state", .{});
        return app_state;
    } else {
        std.log.info("Save file not found", .{});
        var app_state: AppState = undefined;
        app_state.init(gpa);
        return app_state;
    }
}
