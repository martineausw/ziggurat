//! 0.14.1 microlibrary to introduce type constraints.
const std = @import("std");

pub const aux = @import("term/aux.zig");
pub const types = @import("term/types.zig");
pub const ops = @import("term/ops.zig");

pub const Term = @import("term/Term.zig");

/// Example:
/// ```
/// const ziggurat = @import("ziggurat");
///
/// const FloatOrInt = ziggurat.ops.Disjoin(
///     ziggurat.types.int.Has(.{}),
///     ziggurat.types.float.Has(.{}),
/// );
///
/// const OnlyFloatOrInt = Sign(FloatOrInt)
///
/// fn foo(x: anytype) OnlyFloatOrInt(x)(void) {
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
pub fn Sign(T: Term) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (T.eval(actual)) |result| {
                if (!result) if (T.onFail) |onFail|
                    onFail(T, actual);
            } else |err| {
                if (T.onError) |onError|
                    onError(err, T, actual);
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

test Term {
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
        .onFail = struct {
            fn onFail(term: Term, _: anytype) void {
                std.log.err(term.name);
            }
        }.onFail,
    };

    const AlwaysError: Term = .{
        .name = "AlwaysError",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return error.ExampleError;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, _: anytype) void {
                @compileError(term.name ++ ": " ++ @errorName(err));
            }
        }.onError,
    };

    try std.testing.expectEqual(true, AlwaysTrue.eval(void));
    try std.testing.expectEqual(false, AlwaysFalse.eval(void));
    try std.testing.expectEqual(error.ExampleError, AlwaysError.eval(void));
}

test ops {
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
        .onFail = struct {
            fn onFail(term: Term, _: anytype) void {
                std.log.err(term.name);
            }
        }.onFail,
    };

    const TrueOrFalse = ops.Disjoin(AlwaysFalse, AlwaysTrue);
    const TrueAndFalse = ops.Conjoin(AlwaysFalse, AlwaysTrue);
    const NotFalse = ops.Negate(AlwaysFalse);

    try std.testing.expectEqual(true, TrueOrFalse.eval(void));
    try std.testing.expectEqual(false, TrueAndFalse.eval(void));
    try std.testing.expectEqual(true, NotFalse.eval(void));
}

test types {
    const Int = types.int.Has(.{});
    const Float = types.float.Has(.{});
    const Pointer = types.pointer.Has(.{});

    try std.testing.expectEqual(true, Int.eval(usize));
    try std.testing.expectEqual(error.UnexpectedInfo, Int.eval(bool));
    try std.testing.expectEqual(true, Float.eval(f128));
    try std.testing.expectEqual(error.UnexpectedInfo, Float.eval(usize));
    try std.testing.expectEqual(true, Pointer.eval([]const u8));
    try std.testing.expectEqual(error.UnexpectedInfo, Pointer.eval([3]u8));
}

test {
    std.testing.refAllDecls(@This());
}
