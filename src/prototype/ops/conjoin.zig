//! `conjoin` definition
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

const info_validator = info.init(.{
    .array = true,
    .vector = true,
    .pointer = true,
});

/// Boolean AND of given prototypes
pub fn conjoin(prototypes: anytype) Prototype {
    return .{
        .name = "Conjoin",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var results: [prototypes.len]bool = undefined;
                var errs: [prototypes.len]?anyerror = undefined;

                for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                inline for (prototypes, 0..) |prototype, i| {
                    if (prototype.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                    }
                }

                var result = results[0];

                for (1..results.len) |i|
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
                var results = [prototypes.len]bool{};
                var errs = [prototypes.len]?anyerror{};

                for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                for (prototypes, 0..) |proto, i| {
                    if (proto.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                    }
                }

                for (0..prototypes.len) |i| {
                    if (errs[i]) |e| {
                        prototypes[i].onError(e, prototype, actual);
                    }
                }
            }
        }.onError,
    };
}

test conjoin {
    _ = conjoin(.{
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

    try std.testing.expectEqual(true, conjoin(.{is_true}).eval(void));
    try std.testing.expectEqual(true, conjoin(.{ is_true, is_true }).eval(void));
    try std.testing.expectEqual(true, conjoin(.{ is_true, is_true, is_true }).eval(void));
}

test "evaluates conjoin to false" {
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

    try std.testing.expectEqual(false, conjoin(.{is_false}).eval(void));
    try std.testing.expectEqual(false, conjoin(.{ is_true, is_false }).eval(void));
    try std.testing.expectEqual(false, conjoin(.{ is_false, is_true }).eval(void));
    try std.testing.expectEqual(false, conjoin(.{ is_true, is_true, is_false }).eval(void));
}

test "evaluates conjoin to error" {
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

    const is_error: Prototype = .{
        .name = "error",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return error.Error;
            }
        }.eval,
    };

    try std.testing.expectEqual(error.Error, conjoin(.{is_error}).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(.{ is_true, is_error }).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(.{ is_false, is_error }).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(.{ is_error, is_false }).eval(void));
    try std.testing.expectEqual(error.Error, conjoin(.{ is_true, is_true, is_error }).eval(void));
}
