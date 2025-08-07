//! 0.14.1 microlibrary to introduce type constraints.
const std = @import("std");

pub const Term = @import("term/Term.zig");
pub const params = @import("term/params.zig");
pub const ops = @import("term/ops.zig");
pub const types = @import("term/types.zig");
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
pub fn Sign(t: Term) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (t.eval(actual)) |result| {
                if (!result) if (t.onFail) |onFail|
                    onFail(t, actual);
            } else |err| {
                if (t.onError) |onError|
                    onError(t, actual, err);
            }

            return struct {
                pub fn returns(comptime return_type: type) type {
                    return return_type;
                }
            }.returns;
        }
    }.validate;
}

test Sign {
    const AnyRuntimeInt: Term = .{
        .name = "AnyRuntimeInt",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    };

    const term_value: Term = AnyRuntimeInt;
    const argument_value: u32 = 0;
    const return_type: type = void;

    _ = Sign(term_value)(argument_value)(return_type);

    const Signed = Sign(term_value);
    _ = Signed(argument_value)(return_type);
}

test {
    std.testing.refAllDecls(@This());
}
