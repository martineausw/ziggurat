//! Prototype operation *conjoin*.
//!
//! Asserts an *actual* value to pass at least one evaluation of provided
//! prototypes.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

pub const info_validator = info.init(.{
    .array = true,
    .pointer = true,
    .vector = true,
});

/// Boolean OR of prototypes' evaluation results.
pub fn disjoin(prototypes: anytype) Prototype {
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

                for (1..results.len) |i|
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
    _ = disjoin(.{
        Prototype{
            .name = "prototype",
            .eval = struct {
                fn eval(actual: anytype) !bool {
                    _ = actual;
                    return true;
                }
            }.eval,
        },
    });
}

test "evaluates conjoin to true" {
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

    try std.testing.expectEqual(true, disjoin(.{is_true}).eval(void));
    try std.testing.expectEqual(true, disjoin(.{ is_true, is_true }).eval(void));
    try std.testing.expectEqual(true, disjoin(.{ is_false, is_true }).eval(void));
    try std.testing.expectEqual(true, disjoin(.{ is_true, is_false }).eval(void));
    try std.testing.expectEqual(true, disjoin(.{ is_true, is_true, is_false }).eval(void));
}

test "evaluates conjoin to false" {
    const is_false: Prototype = .{
        .name = "false",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try std.testing.expectEqual(false, disjoin(.{is_false}).eval(void));
    try std.testing.expectEqual(false, disjoin(.{ is_false, is_false }).eval(void));
    try std.testing.expectEqual(false, disjoin(.{ is_false, is_false, is_false }).eval(void));
}

test "evaluates conjoin to error" {
    const is_false: Prototype = .{
        .name = "false",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    const is_error: Prototype = .{
        .name = "error",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return error.Error;
            }
        }.eval,
    };

    try std.testing.expectEqual(error.Error, disjoin(.{is_error}).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(.{ is_error, is_error }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(.{ is_false, is_error }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(.{ is_error, is_false }).eval(void));
    try std.testing.expectEqual(error.Error, disjoin(.{ is_error, is_false, is_error }).eval(void));
}
