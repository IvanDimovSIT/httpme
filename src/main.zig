const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;
const app = httpme.app;
const AppState = app.app_state.AppState;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var app_state: AppState = undefined;
    app_state.init(gpa);
    defer app_state.deinit();
    const loaded_app_state_model = app.persistence.loadAppState(io, gpa) catch null;
    if (loaded_app_state_model) |parsed_app_state| {
        defer parsed_app_state.deinit();
        const app_state_model = parsed_app_state.value;
        app_state.visit_counter = .init(app_state_model.visit_counter);
        app_state.id_counter = .init(app_state_model.id_counter);
        for (app_state_model.todo_list) |list_item| {
            const newListItem = try list_item.clone(gpa);
            try app_state.todo_list.append(gpa, newListItem);
        }
        std.log.info("Loaded saved state", .{});
    } else {
        std.log.info("Save file not found", .{});
    }

    try http.startHttpServer(AppState, gpa, .{ .endpoint_handlers = &app.endpoints.paths, .app_state = &app_state });
}
