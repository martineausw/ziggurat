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
pub fn sign(T: Term) fn (actual: anytype) fn (comptime return_type: type) type {
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

test sign {
    const runtime_int: Term = .{
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

    const term_value: Term = runtime_int;
    const argument_value: u32 = 0;
    const return_type: type = void;

    _ = sign(term_value)(argument_value)(return_type);

    const signed = sign(term_value);
    _ = signed(argument_value)(return_type);
}

test Term {
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
        .onFail = struct {
            fn onFail(term: Term, _: anytype) void {
                std.log.err(term.name);
            }
        }.onFail,
    };

    const always_error: Term = .{
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

    try std.testing.expectEqual(true, always_true.eval(void));
    try std.testing.expectEqual(false, always_false.eval(void));
    try std.testing.expectEqual(error.ExampleError, always_error.eval(void));
}

test ops {
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
        .onFail = struct {
            fn onFail(term: Term, _: anytype) void {
                std.log.err(term.name);
            }
        }.onFail,
    };

    const true_or_false = ops.disjoin(always_false, always_true);
    const true_and_false = ops.conjoin(always_false, always_true);
    const not_false = ops.negate(always_false);

    try std.testing.expectEqual(true, true_or_false.eval(void));
    try std.testing.expectEqual(false, true_and_false.eval(void));
    try std.testing.expectEqual(true, not_false.eval(void));
}

test types {
    const int = types.Int.init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = null,
    });
    const float = types.Float.init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
    });
    const pointer = types.Pointer.init(.{
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
        .size = .{
            .one = null,
            .slice = null,
            .many = null,
            .c = null,
        },
    });

    try std.testing.expectEqual(
        true,
        int.eval(usize),
    );

    try std.testing.expectEqual(
        error.UnexpectedType,
        int.eval(bool),
    );

    try std.testing.expectEqual(
        true,
        float.eval(f128),
    );

    try std.testing.expectEqual(
        error.UnexpectedType,
        float.eval(usize),
    );

    try std.testing.expectEqual(
        true,
        pointer.eval([]const u8),
    );

    try std.testing.expectEqual(
        error.UnexpectedType,
        pointer.eval([3]u8),
    );
}

test aux {
    const info = aux.info.init(.{
        .type = null,
        .void = null,
        .bool = null,
        .noreturn = null,
        .int = null,
        .float = null,
        .pointer = null,
        .array = null,
        .@"struct" = null,
        .comptime_float = null,
        .comptime_int = null,
        .undefined = null,
        .null = null,
        .optional = null,
        .error_union = null,
        .error_set = null,
        .@"enum" = null,
        .@"union" = null,
        .@"fn" = null,
        .@"opaque" = null,
        .frame = null,
        .@"anyframe" = null,
        .vector = null,
        .enum_literal = null,
    });
    const interval = aux.interval.init(comptime_int, .{
        .min = null,
        .max = null,
    });
    const @"type" = aux.type.init;

    try std.testing.expectEqual(
        true,
        info.eval(void),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(0),
    );

    try std.testing.expectEqual(
        true,
        @"type".eval(usize),
    );
}

test {
    std.testing.refAllDecls(@This());
}
