//! Prototype operation *conjoin*.
//!
//! Asserts an *actual* value to pass at least one evaluation of provided
//! prototypes.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("../aux/FiltersTypeInfo.zig");

const Self = @This();

/// Boolean OR of prototypes' evaluation results.
pub fn any(comptime prototypes: []const Prototype) Prototype {
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

test any {
    _ = any(&.{.true});
}

test "evaluates any to true" {
    try std.testing.expectEqual(true, any(&.{.true}).eval(void));
    try std.testing.expectEqual(true, any(&.{ .true, .true }).eval(void));
    try std.testing.expectEqual(true, any(&.{ .false, .true }).eval(void));
    try std.testing.expectEqual(true, any(&.{ .true, .false }).eval(void));
    try std.testing.expectEqual(true, any(&.{ .true, .true, .false }).eval(void));
}

test "evaluates any to false" {
    try std.testing.expectEqual(false, any(&.{.false}).eval(void));
    try std.testing.expectEqual(false, any(&.{ .false, .false }).eval(void));
    try std.testing.expectEqual(false, any(&.{ .false, .false, .false }).eval(void));
}

test "evaluates any to error" {
    try std.testing.expectEqual(error.Error, any(&.{
        .@"error",
    }).eval(void));
    try std.testing.expectEqual(error.Error, any(&.{ .@"error", .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, any(&.{ .false, .@"error" }).eval(void));
    try std.testing.expectEqual(error.Error, any(&.{ .@"error", .false }).eval(void));
    try std.testing.expectEqual(error.Error, any(&.{ .@"error", .false, .@"error" }).eval(void));
}
