const std = @import("std");

pub const AppState = struct {
    visit_counter: std.atomic.Value(u64) = .init(0),
};
