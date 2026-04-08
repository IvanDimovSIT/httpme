const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;
const app = httpme.app;
const AppState = app.app_state.AppState;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var app_state: AppState = undefined;
    app_state.init(gpa);
    defer app_state.deinit();
    try http.startHttpServer(AppState, gpa, .{ .endpoint_handlers = &app.endpoints.paths, .app_state = &app_state });
}
