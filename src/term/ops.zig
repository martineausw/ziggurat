//! Boolean operations for `Term.eval` implementations.
const std = @import("std");
const testing = std.testing;
const Term = @import("Term.zig");

/// Boolean NOT of given `term`
pub fn negate(term: Term) Term {
    return .{
        .name = std.fmt.comptimePrint("(NOT {s})", .{term.name}),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (term.eval(actual)) |result| {
                    return !result;
                } else |err| {
                    return err;
                }
            }
        }.eval,
        .onError = term.onError,
    };
}

test negate {
    const always_true: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) anyerror!bool {
                return true;
            }
        }.eval,
    };

    try testing.expect(false == try negate(always_true).eval(void));
}

const ConjoinError = error{FalseResult};

/// Boolean AND of given `term0` and `term1`
pub fn conjoin(term0: Term, term1: Term) Term {
    return .{
        .name = std.fmt.comptimePrint(
            "({s} AND {s})",
            .{ term0.name, term1.name },
        ),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var result0 = false;
                var result1 = false;

                var err0: ?anyerror = null;
                var err1: ?anyerror = null;

                if (term0.eval(actual)) |result| {
                    result0 = result;
                } else |err| {
                    err0 = err;
                }

                if (term1.eval(actual)) |result| {
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
            fn onError(_: anyerror, term: Term, actual: anytype) void {
                _ = term0.eval(actual) catch |err0|
                    term0.onError(err0, term, actual);
                _ = term1.eval(actual) catch |err1|
                    term1.onError(err1, term, actual);
            }
        }.onError,
    };
}

test conjoin {
    const always_true: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const always_false: Term = .{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try testing.expectEqual(
        true,
        conjoin(always_true, always_true).eval(void),
    );
    try testing.expectEqual(
        false,
        conjoin(always_true, always_false).eval(void),
    );
}

/// Boolean OR of `term0` and `term1`
pub fn disjoin(term0: Term, term1: Term) Term {
    return .{
        .name = std.fmt.comptimePrint(
            "({s} OR {s})",
            .{ term0.name, term1.name },
        ),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var result0 = false;
                var result1 = false;

                var err0: ?anyerror = null;
                var err1: ?anyerror = null;

                if (term0.eval(actual)) |result| {
                    result0 = result;
                } else |err| {
                    err0 = err;
                }

                if (term1.eval(actual)) |result| {
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
            fn onError(_: anyerror, term: Term, actual: anytype) void {
                _ = term0.eval(actual) catch |err0|
                    term0.onError(err0, term, actual);
                _ = term1.eval(actual) catch |err1|
                    term1.onError(err1, term, actual);
            }
        }.onError,
    };
}

test disjoin {
    const always_true: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const always_false: Term = .{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try testing.expectEqual(
        true,
        disjoin(always_true, always_true).eval(void),
    );
    try testing.expectEqual(
        true,
        disjoin(always_true, always_false).eval(void),
    );
    try testing.expectEqual(
        false,
        disjoin(always_false, always_false).eval(void),
    );
}

test {
    std.testing.refAllDecls(@This());
}
