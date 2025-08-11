//! Boolean operations for `Prototype.eval` implementations.
const std = @import("std");
const testing = std.testing;
const Prototype = @import("Prototype.zig");

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
    const @"true": Prototype = .{
        .name = "True",
        .eval = struct {
            fn eval(_: anytype) anyerror!bool {
                return true;
            }
        }.eval,
    };

    try testing.expect(false == try negate(@"true").eval(void));
}

const ConjoinError = error{FalseResult};

/// Boolean AND of given `prototype0` and `prototype1`
pub fn conjoin(prototype0: Prototype, prototype1: Prototype) Prototype {
    return .{
        .name = std.fmt.comptimePrint(
            "({s} AND {s})",
            .{ prototype0.name, prototype1.name },
        ),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var result0 = false;
                var result1 = false;

                var err0: ?anyerror = null;
                var err1: ?anyerror = null;

                if (prototype0.eval(actual)) |result| {
                    result0 = result;
                } else |err| {
                    err0 = err;
                }

                if (prototype1.eval(actual)) |result| {
                    result1 = result;
                } else |err| {
                    err1 = err;
                }

                if (result0 and result1) {
                    return true;
                }

                if (err0) |err| {
                    return err;
                }

                if (err1) |err| {
                    return err;
                }

                return false;
            }
        }.eval,
        .onError = struct {
            fn onError(_: anyerror, prototype: Prototype, actual: anytype) void {
                _ = prototype0.eval(actual) catch |err0|
                    prototype0.onError(err0, prototype, actual);
                _ = prototype1.eval(actual) catch |err1|
                    prototype1.onError(err1, prototype, actual);
            }
        }.onError,
    };
}

test conjoin {
    const @"true": Prototype = .{
        .name = "True",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const @"false": Prototype = .{
        .name = "False",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try testing.expectEqual(
        true,
        conjoin(@"true", @"true").eval(void),
    );
    try testing.expectEqual(
        false,
        conjoin(@"true", @"false").eval(void),
    );
}

/// Boolean OR of `prototype0` and `prototype1`
pub fn disjoin(prototype0: Prototype, prototype1: Prototype) Prototype {
    return .{
        .name = std.fmt.comptimePrint(
            "({s} OR {s})",
            .{ prototype0.name, prototype1.name },
        ),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var result0 = false;
                var result1 = false;

                var err0: ?anyerror = null;
                var err1: ?anyerror = null;

                if (prototype0.eval(actual)) |result| {
                    result0 = result;
                } else |err| {
                    err0 = err;
                }

                if (prototype1.eval(actual)) |result| {
                    result1 = result;
                } else |err| {
                    err1 = err;
                }

                if (result0 or result1) {
                    return true;
                }

                if (err0) |err| {
                    return err;
                }

                if (err1) |err| {
                    return err;
                }

                return false;
            }
        }.eval,
        .onError = struct {
            fn onError(_: anyerror, prototype: Prototype, actual: anytype) void {
                _ = prototype0.eval(actual) catch |err0|
                    prototype0.onError(err0, prototype, actual);
                _ = prototype1.eval(actual) catch |err1|
                    prototype1.onError(err1, prototype, actual);
            }
        }.onError,
    };
}

test disjoin {
    const @"true": Prototype = .{
        .name = "true",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const @"false": Prototype = .{
        .name = "false",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try testing.expectEqual(
        true,
        disjoin(@"true", @"true").eval(void),
    );
    try testing.expectEqual(
        true,
        disjoin(@"true", @"false").eval(void),
    );
    try testing.expectEqual(
        false,
        disjoin(@"false", @"false").eval(void),
    );
}

test {
    std.testing.refAllDecls(@This());
}
