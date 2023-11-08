const std = @import("std");

const fs = std.fs;
const Step = std.Build.Step;
pub const Path = std.Build.LazyPath;

const Setup = @This();

const WorkflowKind = enum { Executable, TestSuite };

pub const Settings = struct {
    debug_test: bool = false,
};

pub fn Project(comptime project_name: []const u8) type {
    return struct {
        settings: Settings,
        build: *std.Build,
        target: std.zig.CrossTarget,
        optimize: std.builtin.OptimizeMode,

        // Structs

        pub const Command = struct {
            name: []const u8,
            binary_name: []const u8 = project_name,
            description: []const u8,
            kind: WorkflowKind,
            script_path: Path,

            pub fn toBinary(self: @This(), artifact: *Step.Run) Binary {
                return Binary{ .name = self.name, .binary_name = self.binary_name, .description = self.description, .kind = self.kind, .artifact = artifact };
            }
        };

        pub const Binary = struct { name: []const u8, binary_name: []const u8 = project_name, description: []const u8, kind: WorkflowKind, artifact: *Step.Run };

        // OOP stuff

        const Self = @This();

        pub fn init(build: *std.Build, settings: Settings) Self {
            return Self{ .settings = settings, .build = build, .target = build.standardTargetOptions(.{}), .optimize = build.standardOptimizeOption(.{}) };
        }

        // Methods

        /// Add a compiled binary to the setup
        pub fn binary(self: Self, cmd: Command) !*Step.Compile {
            const b = self.build;

            const bin = switch (cmd.kind) {
                .Executable => b.addExecutable(.{
                    .name = cmd.binary_name,
                    .root_source_file = cmd.script_path,
                    .target = self.target,
                    .optimize = self.optimize,
                }),
                .TestSuite => blk: {
                    var name_buf = std.ArrayList(u8).init(b.allocator);
                    defer name_buf.deinit();

                    try name_buf.appendSlice(cmd.binary_name);
                    try name_buf.appendSlice("-test");

                    const full_name = try b.allocator.dupe(u8, name_buf.items);

                    break :blk b.addTest(.{
                        .name = full_name,
                        .root_source_file = cmd.script_path,
                        .target = self.target,
                        .optimize = self.optimize,
                    });
                },
            };

            const should_install = cmd.kind == WorkflowKind.Executable or self.settings.debug_test;

            if (should_install) {
                b.installArtifact(bin);
            }

            self.assembleSteps(cmd.toBinary(b.addRunArtifact(bin)));

            return bin;
        }

        const TaggedCommand = struct {
            name: []const u8,
            binary_name: []const u8 = project_name,
            description: []const u8,
            script_path: Path,
        };

        /// Add a compiled executable binary to the setup
        pub fn exe(self: Self, cmd: TaggedCommand) !*Step.Compile {
            return try self.binary(.{
                .name = cmd.name,
                .kind = .Executable,
                .description = cmd.description,
                .script_path = cmd.script_path,
            });
        }

        /// Add a compiled test suite binary to the setup
        pub fn testSuite(self: Self, cmd: TaggedCommand) !*Step.Compile {
            return try self.binary(.{
                .name = cmd.name,
                .binary_name = cmd.binary_name,
                .kind = .TestSuite,
                .description = cmd.description,
                .script_path = cmd.script_path,
            });
        }

        /// Search for all files ending in any of the extensions listed in `options.allowed_extensions` within the `options.base_path` directory. The caller is responsible for freeing the memory allocated to the returned ArrayList
        pub fn getPaths(self: Self, options: GetPathsOptions) !std.ArrayList([]const u8) {
            return Setup.getPaths(self.build.allocator, options);
        }

        fn assembleSteps(self: Self, bin: Binary) void {
            const b = self.build;

            bin.artifact.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                bin.artifact.addArgs(args);
            }

            const run_step = b.step(bin.name, bin.description);
            run_step.dependOn(&bin.artifact.step);
        }
    };
}

pub const GetPathsOptions = struct {
    base_path: Path,
    return_empty: bool = false,
    allowed_extensions: []const []const u8 = &.{ ".c", ".cpp", ".cxx", ".c++", ".cc" },
};

/// Search for all files ending in any of the extensions listed in `options.allowed_extensions` within the `options.base_path` directory. The caller is responsible for freeing the memory allocated to the returned ArrayList
pub fn getPaths(allocator: std.mem.Allocator, options: GetPathsOptions) !std.ArrayList([]const u8) {
    var sources = std.ArrayList([]const u8).init(allocator);

    const cwd = fs.cwd();

    const OpenErr = fs.Dir.OpenError;

    // Create iterable directory, handling when directory doesn't exist
    var dir = cwd.openIterableDir(options.base_path.path, .{}) catch |err| switch (err) {
        OpenErr.FileNotFound => {
            std.log.warn("{s} was not found!", .{options.base_path.path});

            if (options.return_empty) {
                return sources;
            }

            return err;
        },
        else => return err,
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    while (try walker.next()) |entry| {
        const ext = fs.path.extension(entry.basename);

        const include_file = for (options.allowed_extensions) |e| {
            if (std.mem.eql(u8, ext, e)) {
                break true;
            }
        } else false;

        if (include_file) {
            const full_path = try fs.path.join(allocator, &.{ options.base_path.path, entry.path });

            try sources.append(full_path);
        }
    }

    return sources;
}
