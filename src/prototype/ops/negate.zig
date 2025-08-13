///! `negate` definition.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");

/// Boolean NOT of given `prototype`
pub fn negate(prototype: Prototype) Prototype {
    return .{
        .name = std.fmt.comptimePrint("(NOT {s})", .{prototype.name}),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (prototype.eval(actual)) |result| {
                    return !result;
                } else |err| {
                    return err;
                }
            }
        }.eval,
        .onError = prototype.onError,
    };
}

test negate {
    _ = negate(Prototype{
        .name = "prototype",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = actual;
                return true;
            }
        }.eval,
    });
}

test "evaluates negate to true" {
    const is_true: Prototype = .{
        .name = "true",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };

    const is_false: Prototype = .{
        .name = "false",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try std.testing.expectEqual(true, negate(is_false).eval(void));
    try std.testing.expectEqual(true, negate(negate(is_true)).eval(void));
}

test "evaluates negate to false" {
    const is_true: Prototype = .{
        .name = "true",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };

    const is_false: Prototype = .{
        .name = "false",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try std.testing.expectEqual(false, negate(is_true).eval(void));
    try std.testing.expectEqual(false, negate(negate(is_false)).eval(void));
}
