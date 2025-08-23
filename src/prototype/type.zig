const std = @import("std");

const Self = @This();

const Prototype = @import("Prototype.zig");

const TypeError = error{
    AssertsTypeValue,
};

pub const Error = TypeError;

pub const init: Prototype = .{
    .name = @typeName(Self),

    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            if (@TypeOf(actual) != type) return TypeError.AssertsTypeValue;
            return true;
        }
    }.eval,
    .onError = struct {
        fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
            switch (err) {
                else => @compileError(std.fmt.comptimePrint("{s}.{s} expects `type`, actual: {s}", .{
                    prototype.name,
                    @errorName(err),
                    @typeName(@TypeOf(actual)),
                })),
            }
        }
    }.onError,
};

test "is type" {
    try std.testing.expectEqual(true, init.eval(usize));
    try std.testing.expectEqual(true, init.eval(u8));
    try std.testing.expectEqual(true, init.eval(i128));
    try std.testing.expectEqual(true, init.eval(i8));
    try std.testing.expectEqual(true, init.eval(f128));
    try std.testing.expectEqual(true, init.eval(f16));
    try std.testing.expectEqual(true, init.eval(bool));
    try std.testing.expectEqual(true, init.eval(?bool));
    try std.testing.expectEqual(true, init.eval(comptime_float));
    try std.testing.expectEqual(true, init.eval(comptime_int));
    try std.testing.expectEqual(true, init.eval(struct {}));
    try std.testing.expectEqual(true, init.eval(union {}));
    try std.testing.expectEqual(true, init.eval(enum {}));
    try std.testing.expectEqual(true, init.eval(error{}));
    try std.testing.expectEqual(true, init.eval(fn () void));
    try std.testing.expectEqual(true, init.eval([]const u8));
    try std.testing.expectEqual(true, init.eval([:0]u8));
    try std.testing.expectEqual(true, init.eval([*]enum {}));
    try std.testing.expectEqual(
        true,
        init.eval(*const volatile struct {}),
    );
    try std.testing.expectEqual(true, init.eval([3]i128));
    try std.testing.expectEqual(true, init.eval(@Vector(3, f128)));
    try std.testing.expectEqual(true, init.eval(@TypeOf(null)));
    try std.testing.expectEqual(true, init.eval(@TypeOf(undefined)));
    try std.testing.expectEqual(true, init.eval(void));
}
