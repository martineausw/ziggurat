//! Consists of `Term` abstract and `Sign` function to introduce type
//! constraints within function signatures

const std = @import("std");
const testing = std.testing;

const TermConfig = struct {
    name: ?[]const u8 = null,
    desc: ?[]const u8 = null,
    onPass: ?*const fn (actual: anytype) bool = null,
    onFail: ?*const fn (actual: anytype) bool = null,
};

/// `Term` abstract
///
/// Defines a condition that is evaluated when supplied with an argument.
/// Used by `Sign` to cease control flow when evaluation results to a false
/// value.
///
/// Let `actual` be defined as a single arbitrary argument that gets passed
/// through all evaluation steps. `actual` may or may not be indexable and
/// may have meta-data, as given by `@typeInfo(...)`.
pub const Term = struct {
    name: []const u8,
    /// Function pointer that is invoked by `Sign` or other `Term` wrappers.
    ///
    /// `actual: anytype` argument to be evaluated
    /// by the term.
    ///
    /// `Sign` expects final evaluation result to be true in order to continue.
    eval: *const fn (actual: anytype) bool,

    /// Optional function pointer invoked by `Sign` or other `Term` implementations
    /// when `eval` returns true.
    onPass: ?*const fn (actual: anytype) void = null,

    /// Optional function pointer invoked by `Sign` or other `Term` implementations
    /// when `eval` returns false.
    onFail: ?*const fn (actual: anytype) void = null,
};

test Term {
    const AnyRuntimeInt: Term = .{
        .name = "AnyInt",
        .eval = struct {
            fn eval(actual: anytype) bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    };

    const AnyBool = Term{
        .name = "AnyBool",
        .eval = struct {
            fn eval(actual: anytype) bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .bool => true,
                    else => false,
                };
            }
        }.eval,
    };

    try testing.expect(true == AnyRuntimeInt.eval(@as(u32, 0)));
    try testing.expect(false == AnyRuntimeInt.eval(@as(bool, false)));

    try testing.expect(false == AnyBool.eval(@as(u32, 0)));
    try testing.expect(true == AnyBool.eval(@as(bool, false)));
}

/// Example:
/// ```
/// const AnyIntTerm = Int(.{})
/// fn foo(x: anytype) Sign(AnyIntTerm)(x)(void) {
///     ...
/// }
/// ```
///
/// Implementation uses monad(?) pattern, or a series of closures. Calling is as follows:
///
/// ```
/// Sign(term_value: Term)(argument_value: anytype)(function_return_type: type)
/// ```
///
/// Wraps the final term and invoked at return value position of a function signature.
///
/// Term must evaluate to true to continue.
pub fn Sign(term: Term) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            const result = term.eval(actual);
            if (result) {
                if (term.onPass) |onPass| {
                    onPass(actual);
                }
            } else {
                if (term.onFail) |onFail| {
                    onFail(actual);
                } else {
                    @compileError("violated term: " ++ term.name);
                }
            }
            return struct {
                pub fn returns(comptime ret_type: type) type {
                    return ret_type;
                }
            }.returns;
        }
    }.validate;
}

test Sign {
    const ExampleIntTerm: Term = .{
        .name = "example int term",
        .eval = struct {
            fn eval(actual: anytype) bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    };

    const term_value: Term = ExampleIntTerm;
    const argument_value: u32 = 0;
    const return_type: type = void;

    _ = Sign(term_value)(argument_value)(return_type);

    const Signed = Sign(term_value);
    _ = Signed(argument_value)(return_type);
}

test "some test" {
    std.testing.log_level = .err;
    const AlwaysFalse = Term{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) bool {
                return false;
            }
        }.eval,
    };

    _ = AlwaysFalse;

    // _ = Sign(AlwaysFalse)(void)(void);

    const AlwaysTrue = Term{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) bool {
                return true;
            }
        }.eval,
    };

    _ = Sign(AlwaysTrue)(void)(void);

    // const AlwaysTrueOrAlwaysFalse = Term{
    //     .name = AlwaysFalse.name ++ " and " ++ AlwaysTrue.name,
    //     .eval = struct {
    //         fn eval(_: anytype) bool {
    //             return AlwaysTrue.eval(0) and AlwaysFalse.eval(0);
    //         }
    //     }.eval,
    // };

    // _ = Sign(AlwaysTrueOrAlwaysFalse)(0)(void);
}
