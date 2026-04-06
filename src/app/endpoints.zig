const std = @import("std");

const httpme = @import("../root.zig");
const http = httpme.http_server.http;
const EndpointHandler = httpme.http_server.endpoint_handler.EndpointHandler;
const PathHandlerPair = httpme.http_server.endpoint_handler.PathHandlerPair;
const HttpRequest = httpme.http_server.http_request.HttpRequest;
const HttpResponse = httpme.http_server.http_response.HttpResponse;
const HttpResponseType = httpme.http_server.http_response.HttpResponseType;
const AppState = httpme.app.AppState;

pub const paths = [_]PathHandlerPair(AppState){ .{ .path = "/hello", .handler = helloEndpoint }, .{ .path = "/hello/*", .handler = helloAnyEndpoint } };

fn helloEndpoint(req: *HttpRequest(AppState)) !HttpResponse {
    _ = req.app_state.visit_counter.fetchAdd(1, std.builtin.AtomicOrder.monotonic);
    return HttpResponse{ .body = "{\"message\":\"Hello world!\"}", .response_type = .Ok };
}

fn helloAnyEndpoint(req: *HttpRequest(AppState)) !HttpResponse {
    const path_var = req.path_variables[0];
    const param1 = req.getRequestParam("param1") orelse "<missing param1>";
    const visit_count = req.app_state.visit_counter.fetchAdd(1, std.builtin.AtomicOrder.monotonic);

    const response = try std.fmt.allocPrint(req.arena, "{{\"message\":\"Hello {s}!\",\"param1\":\"{s}\",\"visits\":{d}}}", .{ path_var, param1, visit_count });

    return HttpResponse{ .body = response, .response_type = .Ok };
}
