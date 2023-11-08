const std = @import("std");
const setup = @import("setup.zig");

pub fn build(b: *std.Build) !void {
    const template_setup = setup.Project("lab-template").init(b, .{ .debug_test = true });

    const sources = try template_setup.getPaths(.{ .base_path = .{ .path = "src/lib" }, .return_empty = true });
    defer sources.deinit();

    // Run step

    const exe = try template_setup.exe(.{ .name = "run", .description = "Run the app", .script_path = .{ .path = "src/main.cpp" } });

    exe.addCSourceFiles(.{ .files = sources.items, .flags = &.{} });
    exe.linkLibCpp();

    // Test step

    const unit_tests = try template_setup.testSuite(.{ .name = "test", .description = "Run unit tests", .script_path = .{ .path = "test/sanity.zig" } });
    _ = unit_tests;
}
