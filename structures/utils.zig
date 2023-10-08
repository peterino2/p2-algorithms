const std = @import("std");

pub fn assertf(eval: anytype, comptime fmt: []const u8, args: anytype) !void {
    if (!eval) {
        std.debug.print("[Error]: " ++ fmt, args);
        return error.AssertFailure;
    }
}
