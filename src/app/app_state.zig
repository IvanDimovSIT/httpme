const std = @import("std");

pub const TodoItem = struct {
    id: u64,
    name: []u8,
    is_complete: bool,

    pub fn clone(item: *const TodoItem, gpa: std.mem.Allocator) !TodoItem {
        return .{ .id = item.id, .name = try gpa.dupe(u8, item.name), .is_complete = item.is_complete };
    }
};

pub const AppStateModel = struct { visit_counter: u64, todo_list: []TodoItem, id_counter: u64 };

pub const AppState = struct {
    gpa: std.mem.Allocator,
    visit_counter: std.atomic.Value(u64) = .init(0),
    todo_list: std.ArrayList(TodoItem) = .empty,
    id_counter: std.atomic.Value(u64) = .init(0),
    mutex: std.atomic.Mutex = .unlocked,

    pub fn init(self: *AppState, gpa: std.mem.Allocator) void {
        self.* = .{ .gpa = gpa };
    }

    pub fn deinit(self: *AppState) void {
        for (self.todo_list.items) |item| {
            self.gpa.free(item.name);
        }
        self.todo_list.deinit(self.gpa);
    }
};
