const std = @import("std");

test "simple test" {
    var sources = std.ArrayList([]const u8).init(std.testing.allocator);
    defer sources.deinit();

    // Search for all C/C++ files in `src/lib` and add them
    search: {
        const base_path: []const u8 = "src/lib";
        const allowed_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };

        var dir = std.fs.cwd().openIterableDir("../" ++ base_path, .{}) catch |err| switch (err) {
            std.fs.Dir.OpenError.FileNotFound => break :search,
            else => return err,
        };

        var walker = try dir.walk(std.testing.allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const ext = std.fs.path.extension(entry.basename);
            const include_file = for (allowed_exts) |e| {
                if (std.mem.eql(u8, ext, e))
                    break true;
            } else false;

            if (include_file) {
                var path_vec = std.ArrayList(u8).init(std.testing.allocator);
                defer path_vec.deinit();

                try path_vec.appendSlice(base_path ++ "/");
                try path_vec.appendSlice(entry.path);

                const full_path = try std.testing.allocator.dupe(u8, path_vec.items);

                try sources.append(full_path);
            }
        }
    }

    for (sources.items) |value| {
        std.debug.print("path: {s}", .{value});
    }
}
