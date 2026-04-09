const std = @import("std");
const Io = std.Io;
const httpme = @import("../root.zig");
const AppState = httpme.app.app_state.AppState;
const AppStateModel = httpme.app.app_state.AppStateModel;
const TodoItem = httpme.app.app_state.TodoItem;

const save_file_name = "state.json";
const save_directory = "save";

pub fn saveAppState(io: Io, app_state: *const AppStateModel) !void {
    const cwd: std.Io.Dir = std.Io.Dir.cwd();

    cwd.createDir(io, save_directory, .default_dir) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    var output_dir: std.Io.Dir = try cwd.openDir(io, save_directory, .{});
    defer output_dir.close(io);

    const file: std.Io.File = try output_dir.createFile(io, save_file_name, .{});
    defer file.close(io);

    var file_writer = file.writer(io, &.{});
    const writer = &file_writer.interface;

    const formatter = std.json.fmt(app_state, .{});
    try formatter.format(writer);
}

/// returns a parsed AppStateModel that needs to be freed
pub fn loadAppState(io: Io, gpa: std.mem.Allocator) !std.json.Parsed(AppStateModel) {
    const cwd = std.Io.Dir.cwd();

    var output_dir = try cwd.openDir(io, save_directory, .{});
    defer output_dir.close(io);

    const file = try output_dir.openFile(io, save_file_name, .{});
    defer file.close(io);
    const file_size = try file.length(io);

    var file_reader = file.reader(io, &.{});
    const reader = &file_reader.interface;
    const file_contents = try reader.readAlloc(gpa, file_size);
    defer gpa.free(file_contents);

    return std.json.parseFromSlice(AppStateModel, gpa, file_contents, .{ .allocate = .alloc_always });
}
