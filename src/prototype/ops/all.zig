//! Prototype operation *conjoin*.
//!
//! Asserts an *actual* value to pass all evaluations of provided
//! prototypes.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");

const Self = @This();

/// Boolean AND of prototypes' evaluation results.
pub fn all(comptime prototypes: []const Prototype) Prototype {
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var results: [prototypes.len]bool = undefined;
                var errs: [prototypes.len]?anyerror = undefined;

                inline for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                inline for (prototypes, 0..) |prototype, i| {
                    if (comptime prototype.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                        results[i] = false;
                    }
                }

                var result = results[0];

                for (1..prototypes.len) |i|
                    result = result and results[i];

                if (result) {
                    return true;
                }

                for (errs) |err| {
                    if (err) |e| {
                        return e;
                    }
                }

                return false;
            }
        }.eval,
        .onError = struct {
            fn onError(
                _: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                var results: [prototypes.len]bool = undefined;
                var errs: [prototypes.len]?anyerror = undefined;

                inline for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                inline for (prototypes, 0..) |proto, i| {
                    if (proto.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                    }
                }

                for (0..prototypes.len) |i| {
                    if (errs[i]) |e| {
                        prototypes[i].onError.?(e, prototype, actual);
                    }
                }
            }
        }.onError,
    };
}

test all {
    _ = all(&.{.true});
}

test "evaluates conjoin to true" {
    try std.testing.expectEqual(true, all(&.{.true}).eval(void));
    try std.testing.expectEqual(true, all(&.{ .true, .true }).eval(void));
    try std.testing.expectEqual(true, all(&.{ .true, .true, .true }).eval(void));
}

test "evaluates conjoin to false" {
    try std.testing.expectEqual(false, all(&.{.false}).eval(void));
    try std.testing.expectEqual(false, all(&.{ .true, .false }).eval(void));
    try std.testing.expectEqual(false, all(&.{ .false, .true }).eval(void));
    try std.testing.expectEqual(false, all(&.{ .true, .true, .false }).eval(void));
}

test "evaluates conjoin to error" {
    try std.testing.expectEqual(error.Error, all(&.{.@"error"}).eval(void));
    try std.testing.expectEqual(error.Error, all(&.{ .true, .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, all(&.{ .false, .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, all(&.{ .@"error", .false }).eval(void));
    try std.testing.expectEqual(error.Error, all(&.{ .true, .true, .@"error" }).eval(void));
}
