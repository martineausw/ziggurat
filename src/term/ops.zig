/// Boolean operations for `Term.eval` implementations.
const std = @import("std");
const testing = std.testing;
const Term = @import("Term.zig");

/// Boolean NOT of `Term.eval` implementation
pub fn Negate(term: Term) Term {
    return .{
        .name = std.fmt.comptimePrint("(NOT {s})", .{term.name}),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                return !(try term.eval(actual));
            }
        }.eval,
        .onError = term.onError,
    };
}

test Negate {
    const AlwaysTrue: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) anyerror!bool {
                return true;
            }
        }.eval,
    };

    try testing.expect(false == try Negate(AlwaysTrue).eval(void));
}

const ConjoinError = error{FalseResult};

/// Boolean AND of two `Term.eval` implementations
pub fn Conjoin(term0: Term, term1: Term) Term {
    return .{
        .name = std.fmt.comptimePrint("({s} AND {s})", .{ term0.name, term1.name }),
        .eval = struct {
            fn eval(actual: anytype) !bool {
                const eval0 = try term0.eval(actual);
                const eval1 = try term1.eval(actual);

                return eval0 and eval1;
            }
        }.eval,
        .onError = struct {
            fn onError(_: anyerror, term: Term, actual: anytype) void {
                _ = term0.eval(actual) catch |err0| term0.onError(err0, term, actual);
                _ = term1.eval(actual) catch |err1| term1.onError(err1, term, actual);
            }
        }.onError,
    };
}

test Conjoin {
    const AlwaysTrue: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const AlwaysFalse: Term = .{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try testing.expect(true == try Conjoin(AlwaysTrue, AlwaysTrue).eval(void));
    try testing.expect(false == try Conjoin(AlwaysTrue, AlwaysFalse).eval(void));
}

/// Boolean OR of two `Term.eval` implementations
pub fn Disjoin(term0: Term, term1: Term) Term {
    return .{
        .name = std.fmt.comptimePrint(
            "({s} OR {s})",
            .{ term0.name, term1.name },
        ),
        .eval = struct {
            fn eval(actual: anytype) !bool {
                const eval0 = term0.eval(actual) catch false;
                const eval1 = term1.eval(actual) catch false;

                return eval0 or eval1;
            }
        }.eval,
        .onError = struct {
            fn onError(_: anyerror, term: Term, actual: anytype) void {
                _ = term0.eval(actual) catch |err0| term0.onError(err0, term, actual);
                _ = term1.eval(actual) catch |err1| term1.onError(err1, term, actual);
            }
        }.onError,
    };
}

test Disjoin {
    const AlwaysTrue: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const AlwaysFalse: Term = .{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    try testing.expect(true == try Disjoin(AlwaysTrue, AlwaysTrue).eval(void));
    try testing.expect(true == try Disjoin(AlwaysTrue, AlwaysFalse).eval(void));
    try testing.expect(false == try Disjoin(AlwaysFalse, AlwaysFalse).eval(void));
}

test {
    std.testing.refAllDecls(@This());
}
