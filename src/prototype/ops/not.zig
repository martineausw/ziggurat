//! Prototype operation *conjoin*.
//!
//! Asserts an *actual* value to fail evaluation of provided
//! prototype without an error.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");

const Self = @This();

/// Boolean NOT of prototypes evaluation result.
pub fn not(prototype: Prototype) Prototype {
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (comptime prototype.eval(actual)) |result| {
                    return !result;
                } else |err| {
                    return err;
                }
            }
        }.eval,
        .onError = prototype.onError,
    };
}

test not {
    _ = not(Prototype{
        .name = "prototype",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = actual;
                return true;
            }
        }.eval,
    });
}

test "evaluates not to true" {
    try std.testing.expectEqual(true, not(.false).eval(void));
    try std.testing.expectEqual(true, not(not(.true)).eval(void));
}

test "evaluates negate to false" {
    try std.testing.expectEqual(false, not(.true).eval(void));
    try std.testing.expectEqual(false, not(not(.false)).eval(void));
}
