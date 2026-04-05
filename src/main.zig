const std = @import("std");
const Io = std.Io;

const httpme = @import("httpme");
const http = httpme.http_server.http;
const EndpointHandler = httpme.http_server.endpoint_handler.EndpointHandler;
const PathHandlerPair = httpme.http_server.endpoint_handler.PathHandlerPair;
const HttpRequest = httpme.http_server.http_request.HttpRequest;
const HttpResponse = httpme.http_server.http_response.HttpResponse;
const HttpResponseType = httpme.http_server.http_response.HttpResponseType;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const paths = [_]PathHandlerPair{ .{ .path = "/hello", .handler = helloEndpoint }, .{ .path = "/hello/*", .handler = helloAnyEndpoint } };

    try http.startHttpServer(gpa, .{ .endpoint_handlers = &paths });
}

fn helloEndpoint(req: *HttpRequest) !HttpResponse {
    _ = req;
    return HttpResponse{ .body = "{\"message\":\"Hello world!\"}", .response_type = .Ok };
}

fn helloAnyEndpoint(req: *HttpRequest) !HttpResponse {
    const path_var = req.path_variables[0];
    const param1 = req.getRequestParam("param1") orelse "<missing param1>";

    const response = try std.fmt.allocPrint(req.arena, "{{\"message\":\"Hello {s}!\",\"param1\":\"{s}\"}}", .{ path_var, param1 });

    return HttpResponse{ .body = response, .response_type = .Ok };
}
