const std = @import("std");

const fs = std.fs;
const Step = std.Build.Step;
pub const Path = std.Build.LazyPath;

pub const Tag = enum { Executable, TestSuite };

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    cmd_type: Tag,
    path: Path,

    const Self = @This();

    pub fn toBinary(self: Self, artifact: *Step.Run) Binary {
        return Binary{ .name = self.name, .description = self.description, .bin_type = self.cmd_type, .artifact = artifact };
    }
};

pub const Binary = struct { name: []const u8, description: []const u8, bin_type: Tag, artifact: *Step.Run };

pub const Settings = struct {
    debug_test: bool = false,
};

pub fn Project(comptime name: []const u8) type {
    return struct {
        settings: Settings,
        build: *std.Build,
        target: std.zig.CrossTarget,
        optimize: std.builtin.OptimizeMode,

        const Self = @This();

        pub fn init(build: *std.Build, settings: Settings) Self {
            return Self{ .settings = settings, .build = build, .target = build.standardTargetOptions(.{}), .optimize = build.standardOptimizeOption(.{}) };
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

        /// Add a compiled binary to the setup
        pub fn binary(self: Self, cmd: Command) *Step.Compile {
            const b = self.build;

            const bin = switch (cmd.cmd_type) {
                .Executable => b.addExecutable(.{
                    .name = name,
                    .root_source_file = cmd.path,
                    .target = self.target,
                    .optimize = self.optimize,
                }),
                .TestSuite => b.addTest(.{
                    .name = name ++ "-test",
                    .root_source_file = cmd.path,
                    .target = self.target,
                    .optimize = self.optimize,
                }),
            };

            const should_install = cmd.cmd_type == Tag.Executable or self.settings.debug_test;

            if (should_install) {
                b.installArtifact(bin);
            }

            self.assembleSteps(cmd.toBinary(b.addRunArtifact(bin)));

            return bin;
        }

        const TaggedCommand = struct {
            name: []const u8,
            description: []const u8,
            path: Path,
        };

        pub fn exe(self: Self, cmd: TaggedCommand) *Step.Compile {
            return self.binary(.{
                .name = cmd.name,
                .cmd_type = .Executable,
                .description = cmd.description,
                .path = cmd.path,
            });
        }

        pub fn testSuite(self: Self, cmd: TaggedCommand) *Step.Compile {
            return self.binary(.{
                .name = cmd.name,
                .cmd_type = .TestSuite,
                .description = cmd.description,
                .path = cmd.path,
            });
        }
    };
}

pub const GetPathsOptions = struct {
    base_path: Path,
    return_empty: bool,
    allowed_extensions: []const []const u8 = &.{ ".c", ".cpp", ".cxx", ".c++", ".cc" },
};

/// Search for all C/C++ files in `options.base_path`. The caller is responsible for freeing the memory allocated to the returned ArrayList
pub fn getPaths(allocator: std.mem.Allocator, options: GetPathsOptions) !std.ArrayList([]const u8) {
    var sources = std.ArrayList([]const u8).init(allocator);

    const cwd = fs.cwd();

    // Create iterable directory, handling when directory doesn't exist
    var dir = cwd.openIterableDir(options.base_path.path, .{}) catch |err| switch (err) {
        fs.Dir.OpenError.FileNotFound => {
            const cwd_path = try cwd.realpathAlloc(allocator, ".");
            defer allocator.free(cwd_path);

            std.log.warn("{s} was not found!\ncwd: {s}", .{ options.base_path.path, cwd_path });

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
