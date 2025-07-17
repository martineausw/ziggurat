//! Consists of `Term` abstract and `Sign` function to introduce type
//! constraints within function signatures
const std = @import("std");
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
    /// Function pointer that is invoked by `Sign` or other `Term` wrappers.
    ///
    /// `actual: anytype` argument to be evaluated
    /// by the term.
    ///
    /// `Sign` expects final evaluation result to be true in order to continue.
    eval: *const fn (actual: anytype) bool,

    /// Optional function pointer invoked by `Sign` or other `Term` wrappers
    /// when `eval` returns false.
    onFail: ?*const fn (args: anytype) void = null,

    /// Internal dispatch of `eval` function pointer necessary for interface
    /// pattern.
    fn evalFn(self: Term, actual: anytype) bool {
        return self.eval(actual);
    }

    /// Assert term evaluates to true. Abandons control flow when evaluation
    /// result is false.
    ///
    /// - Pneumonically based on "mandatory/mandate"
    pub fn man(self: Term) Term {
        return struct {
            fn eval(actual: anytype) bool {
                if (!self.eval(actual)) unreachable;
                return true;
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Evaluate term at index. Assumes `actual` is indexable.
    pub fn at(self: Term, index: usize) Term {
        return struct {
            fn eval(actual: anytype) bool {
                return self.eval(actual[index]);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Negates evaluation result of term.
    pub fn not(self: Term) Term {
        return struct {
            fn eval(actual: anytype) bool {
                return !self.eval(actual);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Boolean AND operation of evaluation results.
    ///
    /// - Pneumonically based on "necessarily/necessary"
    pub fn nec(self: Term, term: Term) Term {
        return struct {
            fn eval(actual: anytype) bool {
                return self.eval(actual) and term.eval(actual);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Boolean OR operation of evaluation results
    ///
    /// - Pneumonically based on "optionally/optional/opt-in"
    pub fn opt(self: Term, term: Term) Term {
        return struct {
            fn eval(args: anytype) bool {
                return self.eval(args) or term.eval(args);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }
};

test Term {
    const ExampleIntTerm = struct {
        fn eval(actual: anytype) bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .int => true,
                else => false,
            };
        }

        fn impl() Term {
            return .{ .eval = eval };
        }
    }.impl();

    const ExampleBoolTerm = Term{ .eval = struct {
        fn eval(actual: anytype) bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .bool => true,
                else => false,
            };
        }
    }.eval };

    const ExampleBoolOrIntTerm = Term.opt(ExampleBoolTerm, ExampleIntTerm);
    const ImpossibleBoolAndInt = ExampleBoolTerm.nec(ExampleIntTerm);

    try std.testing.expect(true == ExampleIntTerm.eval(@as(u32, 0)));
    try std.testing.expect(false == ExampleIntTerm.eval(@as(bool, false)));

    try std.testing.expect(false == ExampleBoolTerm.eval(@as(u32, 0)));
    try std.testing.expect(true == ExampleBoolTerm.eval(@as(bool, false)));

    try std.testing.expect(true == ExampleBoolOrIntTerm.eval(@as(bool, false)));
    try std.testing.expect(true == ExampleBoolOrIntTerm.eval(@as(u32, 0)));

    try std.testing.expect(false == ImpossibleBoolAndInt.eval(@as(bool, false)));
    try std.testing.expect(false == ImpossibleBoolAndInt.eval(@as(u32, 0)));
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
pub fn Sign(comptime term: Term) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (!term.eval(actual)) {
                // Check if onFail function is defined.
                if (term.onFail) |onFail| {
                    onFail(actual);
                } else {
                    // Exit if contract validation fails
                    unreachable;
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
    const ExampleIntTerm = struct {
        fn eval(actual: anytype) bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .int => true,
                else => false,
            };
        }

        fn impl() Term {
            return .{ .eval = eval };
        }
    }.impl();

    const term_value = @as(Term, ExampleIntTerm);
    const argument_value = @as(u32, 0);
    const return_type = @as(@TypeOf(void), void);

    _ = Sign(term_value)(argument_value)(return_type);

    const Signed = Sign(term_value);
    _ = Signed(argument_value)(return_type);
}
