const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;
const EndpointHandler = httpme.http_server.endpoint_handler.EndpointHandler;
const EndpointPair = httpme.http_server.endpoint_handler.EndpointPair;
const PathHandlerPair = httpme.http_server.endpoint_handler.PathHandlerPair;
const HttpRequest = httpme.http_server.http_request.HttpRequest;
const HttpResponse = httpme.http_server.http_response.HttpResponse;
const HttpResponseType = httpme.http_server.http_response.HttpResponseType;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const paths: [2]PathHandlerPair = .{ .{ .path = "/hello", .handler = helloEndpoint }, .{ .path = "/hello/*", .handler = helloAnyEndpoint } };
    const handler_pairs = try EndpointPair.allocPairs(gpa, &paths);
    defer EndpointPair.dealoc(handler_pairs, gpa);

    try http.startHttpServer(io, gpa, .{ .endpoint_handlers = handler_pairs });
}

fn helloEndpoint(req: *HttpRequest) !HttpResponse {
    _ = req;

    return HttpResponse{ .body = "Hello world!", .response_type = .Ok };
}

fn helloAnyEndpoint(req: *HttpRequest) !HttpResponse {
    const path_var = req.path_variables[0];
    const param1 = req.getRequestParam("param1") orelse "<missing param1>";

    const response = try std.fmt.allocPrint(req.arena, "Hello {s}!\nparam1:{s}\n", .{ path_var, param1 });

    return HttpResponse{ .body = response, .response_type = .Ok };
}
