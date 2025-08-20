//! Prototype operation *conjoin*.
//!
//! Asserts an *actual* value to pass all evaluations of provided
//! prototypes.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");

/// Boolean AND of prototypes' evaluation results.
pub fn conjoin(comptime prototypes: []const Prototype) Prototype {
    return .{
        .name = "Conjoin",
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

test conjoin {
    _ = conjoin(&.{.true});
}

test "evaluates conjoin to true" {
    try std.testing.expectEqual(true, conjoin(&.{.true}).eval(void));
    try std.testing.expectEqual(true, conjoin(&.{ .true, .true }).eval(void));
    try std.testing.expectEqual(true, conjoin(&.{ .true, .true, .true }).eval(void));
}

test "evaluates conjoin to false" {
    try std.testing.expectEqual(false, conjoin(&.{.false}).eval(void));
    try std.testing.expectEqual(false, conjoin(&.{ .true, .false }).eval(void));
    try std.testing.expectEqual(false, conjoin(&.{ .false, .true }).eval(void));
    try std.testing.expectEqual(false, conjoin(&.{ .true, .true, .false }).eval(void));
}

test "evaluates conjoin to error" {
    try std.testing.expectEqual(error.Error, conjoin(&.{.@"error"}).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(&.{ .true, .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(&.{ .false, .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(&.{ .@"error", .false }).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(&.{ .true, .true, .@"error" }).eval(void));
}
