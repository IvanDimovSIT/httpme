const std = @import("std");

const httpme = @import("../root.zig");
const http = httpme.http_server.http;
const persistence = httpme.app.persistence;
const EndpointHandler = httpme.http_server.endpoint_handler.EndpointHandler;
const PathHandlerPair = httpme.http_server.endpoint_handler.PathHandlerPair;
const HttpRequest = httpme.http_server.http_request.HttpRequest;
const HttpResponse = httpme.http_server.http_response.HttpResponse;
const HttpResponseType = httpme.http_server.http_response.HttpResponseType;
const AppState = httpme.app.app_state.AppState;
const AppStateModel = httpme.app.app_state.AppStateModel;
const TodoItem = httpme.app.app_state.TodoItem;

const homePageUrl: PathHandlerPair(AppState) = .{ .method = .Get, .path = "/home", .handler = homePage };
const todoPageUrl: PathHandlerPair(AppState) = .{ .method = .Get, .path = "/todo", .handler = todoListPage };
const todoPageScriptUrl: PathHandlerPair(AppState) = .{ .method = .Get, .path = "/todo_script.js", .handler = todoListScript };
const apiAddItemUrl: PathHandlerPair(AppState) = .{ .method = .Post, .path = "/api/item", .handler = apiAddItem };
const apiGetItemsUrl: PathHandlerPair(AppState) = .{ .method = .Get, .path = "/api/items", .handler = apiGetItems };
const apiToggleCompleteUrl: PathHandlerPair(AppState) = .{ .method = .Put, .path = "/api/items/toggle/*", .handler = apiToggleComplete };
pub const paths = [_]PathHandlerPair(AppState){ homePageUrl, todoPageUrl, apiAddItemUrl, apiGetItemsUrl, apiToggleCompleteUrl, todoPageScriptUrl };

fn homePage(req: *HttpRequest(AppState)) !HttpResponse {
    const visits = req.app_state.visit_counter.fetchAdd(1, .monotonic);
    const html = @embedFile("../web/home_page.html");
    const body = try std.fmt.allocPrint(req.arena, html, .{visits});

    req.app_state.mutex.lockUncancelable(req.io);
    defer req.app_state.mutex.unlock(req.io);
    const app_model = AppStateModel{ .todo_list = req.app_state.todo_list.items, .visit_counter = req.app_state.visit_counter.load(.monotonic), .id_counter = req.app_state.id_counter.load(.monotonic) };
    try persistence.saveAppState(req.io, &app_model, req.app_state.save_path);

    return HttpResponse{ .body = body, .response_type = .Ok, .content_type = "text/html" };
}

const todoListPage = serveStatic("todo_list_page.html", "text/html");
const todoListScript = serveStatic("todo_script.js", "text");

fn serveStatic(comptime file_name: []const u8, comptime content_type: []const u8) *const fn (*HttpRequest(AppState)) anyerror!HttpResponse {
    return struct {
        fn serve(req: *HttpRequest(AppState)) !HttpResponse {
            _ = req;
            const file = @embedFile("../web/" ++ file_name);
            return HttpResponse{ .body = file, .response_type = .Ok, .content_type = content_type };
        }
    }.serve;
}

fn apiToggleComplete(req: *HttpRequest(AppState)) !HttpResponse {
    if (req.path_variables.len != 1) {
        return .{ .response_type = .NotFound };
    }
    const id_str = req.path_variables[0];
    const id = std.fmt.parseInt(u64, id_str, 10) catch {
        return .{ .response_type = .BadRequest };
    };

    req.app_state.mutex.lockUncancelable(req.io);
    defer req.app_state.mutex.unlock(req.io);
    for (req.app_state.todo_list.items, 0..) |item, i| {
        if (item.id == id) {
            req.app_state.todo_list.items[i].is_complete = !item.is_complete;
            const app_model = AppStateModel{ .todo_list = req.app_state.todo_list.items, .visit_counter = req.app_state.visit_counter.load(.monotonic), .id_counter = req.app_state.id_counter.load(.monotonic) };
            try persistence.saveAppState(req.io, &app_model, req.app_state.save_path);

            return .{ .response_type = .NoContent };
        }
    }

    return .{ .response_type = .NotFound };
}

fn apiAddItem(req: *HttpRequest(AppState)) !HttpResponse {
    const TodoItemDto = struct {
        name: []u8,
    };
    var item_parsed = try std.json.parseFromSlice(TodoItemDto, req.arena, req.body, .{});
    defer item_parsed.deinit();

    const item = item_parsed.value;
    std.log.info("apiAddItem input {}", .{item});
    if (std.mem.trim(u8, item.name, &std.ascii.whitespace).len == 0) {
        return .{ .response_type = .BadRequest, .body = "{\"error\":\"Invalid name field\"}" };
    }

    const todo_item = TodoItem{ .id = req.app_state.id_counter.fetchAdd(1, .monotonic), .name = try req.app_state.gpa.dupe(u8, item.name), .is_complete = false };
    req.app_state.mutex.lockUncancelable(req.io);
    defer req.app_state.mutex.unlock(req.io);
    try req.app_state.todo_list.append(req.app_state.gpa, todo_item);
    const app_model = AppStateModel{ .todo_list = req.app_state.todo_list.items, .visit_counter = req.app_state.visit_counter.load(.monotonic), .id_counter = req.app_state.id_counter.load(.monotonic) };
    try persistence.saveAppState(req.io, &app_model, req.app_state.save_path);

    return .{ .response_type = .Created };
}

fn apiGetItems(req: *HttpRequest(AppState)) !HttpResponse {
    req.app_state.mutex.lockUncancelable(req.io);
    defer req.app_state.mutex.unlock(req.io);

    const json_buffer = try req.arena.alloc(u8, 64 * 1024);
    @memset(json_buffer, 0);
    const json_formatter = std.json.fmt(req.app_state.todo_list.items, .{});
    var writer = std.Io.Writer.fixed(json_buffer);
    try json_formatter.format(&writer);
    const end = std.mem.indexOfScalar(u8, json_buffer, 0) orelse 0;
    const body = json_buffer[0..end];

    return .{ .body = body };
}
