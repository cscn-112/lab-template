const std = @import("std");
const setup = @import("setup_mock.zig");

test "path finding" {
    const sources = try setup.getPaths(std.testing.allocator, .{ .base_path = .{ .path = "lib" }, .return_empty = true });

    for (sources.items) |value| {
        std.debug.print("path: {s}", .{value});
    }
}
