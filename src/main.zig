const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;
const app = httpme.app;
const AppState = app.app_state.AppState;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var app_state = try allocAppState(io, gpa, init.environ_map);
    defer app_state.deinit();

    try http.startHttpServer(AppState, io, gpa, .{ .endpoint_handlers = &app.endpoints.paths, .app_state = &app_state });
}

fn allocAppState(io: Io, gpa: std.mem.Allocator, environ_map: *std.process.Environ.Map) !AppState {
    const save_path = environ_map.get("APP_SAVE_PATH") orelse return error.MissingAppSavePathEnvironment;
    const loaded_app_state = app.persistence.loadAppState(io, gpa, save_path) catch null;
    if (loaded_app_state) |app_state| {
        std.log.info("Loaded saved state on '{s}'", .{save_path});
        return app_state;
    } else {
        std.log.info("Save file not found on '{s}'", .{save_path});
        var app_state: AppState = undefined;
        app_state.init(gpa, save_path);
        return app_state;
    }
}
