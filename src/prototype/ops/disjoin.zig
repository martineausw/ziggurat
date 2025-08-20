//! Prototype operation *conjoin*.
//!
//! Asserts an *actual* value to pass at least one evaluation of provided
//! prototypes.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("../aux/FiltersTypeInfo.zig");

/// Boolean OR of prototypes' evaluation results.
pub fn disjoin(comptime prototypes: []const Prototype) Prototype {
    return .{
        .name = "disjoin",
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
                    result = result or results[i];

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
        .onFail = struct {
            fn onFail(
                prototype: Prototype,
                actual: anytype,
            ) void {
                var results: [prototypes.len]bool = undefined;
                var errs: [prototypes.len]?anyerror = undefined;

                inline for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                for (0..prototypes.len) |i| {
                    if (errs[i]) |e| {
                        prototypes[i].onError.?(e, prototype, actual);
                    }
                }
            }
        }.onFail,
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

                inline for (prototypes, 0..) |p, i| {
                    if (comptime p.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                        results[i] = false;
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

test disjoin {
    _ = disjoin(&.{.true});
}

test "evaluates conjoin to true" {
    try std.testing.expectEqual(true, disjoin(&.{.true}).eval(void));
    try std.testing.expectEqual(true, disjoin(&.{ .true, .true }).eval(void));
    try std.testing.expectEqual(true, disjoin(&.{ .false, .true }).eval(void));
    try std.testing.expectEqual(true, disjoin(&.{ .true, .false }).eval(void));
    try std.testing.expectEqual(true, disjoin(&.{ .true, .true, .false }).eval(void));
}

test "evaluates conjoin to false" {
    try std.testing.expectEqual(false, disjoin(&.{.false}).eval(void));
    try std.testing.expectEqual(false, disjoin(&.{ .false, .false }).eval(void));
    try std.testing.expectEqual(false, disjoin(&.{ .false, .false, .false }).eval(void));
}

test "evaluates conjoin to error" {
    try std.testing.expectEqual(error.Error, disjoin(&.{
        .@"error",
    }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(&.{ .@"error", .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(&.{ .false, .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(&.{ .@"error", .false }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(&.{ .@"error", .false, .@"error" }).eval(void));
}
