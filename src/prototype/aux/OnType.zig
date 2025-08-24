const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");
const Type = @import("../Type.zig");

const OnTypeError = error{AssertsOnType};

pub const Error = OnTypeError || Type.Error;
pub const Params = ?Prototype;

pub fn init(params: Params) Prototype {
    const is_type_value = Type.init;

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) !bool {
                _ = try Type.init.eval(actual);
                if (params) |prototype| {
                    return try prototype.eval(actual);
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.AssertsTypeValue,
                    => is_type_value.onError.?(err, prototype, actual),

                    Error.AssertsOnType,
                    => params.?.onError.?(
                        try prototype.eval(actual),
                        prototype,
                        actual,
                    ),
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "on type" {
    try testing.expectEqual(true, init(.true).eval(bool));
    try testing.expectEqual(true, init(.true).eval(usize));
    try testing.expectEqual(true, init(.true).eval(i128));
    try testing.expectEqual(true, init(.true).eval(u128));
    try testing.expectEqual(true, init(.true).eval(f128));
    try testing.expectEqual(true, init(.true).eval(comptime_int));
    try testing.expectEqual(true, init(.true).eval(comptime_float));
    try testing.expectEqual(true, init(.true).eval(struct {}));
    try testing.expectEqual(true, init(.true).eval(union {}));
    try testing.expectEqual(true, init(.true).eval(enum {}));
    try testing.expectEqual(true, init(.true).eval(error{}));
    try testing.expectEqual(true, init(.true).eval([3]usize));
    try testing.expectEqual(true, init(.true).eval(@Vector(3, f128)));
    try testing.expectEqual(true, init(.true).eval(fn () void));
    try testing.expectEqual(true, init(.true).eval(*const enum {}));
    try testing.expectEqual(true, init(.true).eval([]const u8));
    try testing.expectEqual(true, init(.true).eval([:0]u8));
    try testing.expectEqual(true, init(.true).eval([*]struct {}));
}

test "fails on type" {
    try testing.expectEqual(false, init(.false).eval(bool));
    try testing.expectEqual(false, init(.false).eval(usize));
    try testing.expectEqual(false, init(.false).eval(i128));
    try testing.expectEqual(false, init(.false).eval(u128));
    try testing.expectEqual(false, init(.false).eval(f128));
    try testing.expectEqual(false, init(.false).eval(comptime_int));
    try testing.expectEqual(false, init(.false).eval(comptime_float));
    try testing.expectEqual(false, init(.false).eval(struct {}));
    try testing.expectEqual(false, init(.false).eval(union {}));
    try testing.expectEqual(false, init(.false).eval(enum {}));
    try testing.expectEqual(false, init(.false).eval(error{}));
    try testing.expectEqual(false, init(.false).eval([3]usize));
    try testing.expectEqual(false, init(.false).eval(@Vector(3, f128)));
    try testing.expectEqual(false, init(.false).eval(fn () void));
    try testing.expectEqual(false, init(.false).eval(*const enum {}));
    try testing.expectEqual(false, init(.false).eval([]const u8));
    try testing.expectEqual(false, init(.false).eval([:0]u8));
    try testing.expectEqual(false, init(.false).eval([*]struct {}));

    try testing.expectEqual(error.Error, init(.@"error").eval(bool));
    try testing.expectEqual(error.Error, init(.@"error").eval(usize));
    try testing.expectEqual(error.Error, init(.@"error").eval(i128));
    try testing.expectEqual(error.Error, init(.@"error").eval(u128));
    try testing.expectEqual(error.Error, init(.@"error").eval(f128));
    try testing.expectEqual(error.Error, init(.@"error").eval(comptime_int));
    try testing.expectEqual(error.Error, init(.@"error").eval(comptime_float));
    try testing.expectEqual(error.Error, init(.@"error").eval(struct {}));
    try testing.expectEqual(error.Error, init(.@"error").eval(union {}));
    try testing.expectEqual(error.Error, init(.@"error").eval(enum {}));
    try testing.expectEqual(error.Error, init(.@"error").eval(error{}));
    try testing.expectEqual(error.Error, init(.@"error").eval([3]usize));
    try testing.expectEqual(error.Error, init(.@"error").eval(@Vector(3, f128)));
    try testing.expectEqual(error.Error, init(.@"error").eval(fn () void));
    try testing.expectEqual(error.Error, init(.@"error").eval(*const enum {}));
    try testing.expectEqual(error.Error, init(.@"error").eval([]const u8));
    try testing.expectEqual(error.Error, init(.@"error").eval([:0]u8));
    try testing.expectEqual(error.Error, init(.@"error").eval([*]struct {}));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsTypeValue, init(.true).eval(true));
}
