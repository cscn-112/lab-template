const std = @import("std");
const setup = @import("setup.zig");

pub fn build(b: *std.Build) !void {
    const set_up = setup.Project("lab-template").init(b, .{ .debug_test = true });

    const sources = try setup.getPaths(b.allocator, .{ .base_path = .{ .path = "src/lib" }, .return_empty = true });
    defer sources.deinit();

    const cppFlags: []const []const u8 = &.{};

    // Run step

    const exe = set_up.exe(.{ .name = "run", .description = "Run the app", .path = .{ .path = "src/main.cpp" } });

    exe.addCSourceFiles(.{ .files = sources.items, .flags = cppFlags });
    exe.linkLibCpp();

    // Test step

    const unit_tests = set_up.testSuite(.{ .name = "test", .description = "Run unit tests", .path = .{ .path = "src/sanity_test.zig" } });

    unit_tests.addCSourceFiles(.{ .files = sources.items, .flags = cppFlags });
    unit_tests.linkLibCpp();
}
