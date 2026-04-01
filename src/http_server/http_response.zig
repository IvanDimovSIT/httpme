pub const ResponseType = enum(u8) {
    Ok = 200,
    BadRequest = 400,
    InternalServerError = 500,
};

pub const HttpResponse = struct { response_type: ResponseType, body: []const u8 };
