//! Prototype for `type` value with float type info.
//!
//! `eval` asserts float type within parameters:
//!
//! - `bits`, type info interval assertion
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");

const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

const FloatError = error{
    InvalidArgument,
    AssertsMinBits,
    AssertsMaxBits,
};

/// Errors returned by `eval`
pub const Error = FloatError;

/// Validates type info of `actual` to continue.
pub const info_validator = info.init(.{
    .float = true,
});

/// Associated with `std.builtin.Type.Float.bits`
pub const Params = struct {
    /// Evaluates against `std.builtin.Type.Float.bits`
    bits: interval.Params(u16) = .{},
};

/// Expects runtime float type value.
///
/// `actual` is runtime float type value, otherwise returns error.
///
/// `actual` type info `bits` is within given `params`, otherwise returns
/// error.
pub fn init(params: Params) Prototype {
    const bits_validator = interval.init(u16, params.bits);

    return .{
        .name = "Float",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => FloatError.InvalidArgument,
                        else => unreachable,
                    };

                _ = bits_validator.eval(@typeInfo(actual).float.bits) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin,
                        => FloatError.AssertsMinBits,
                        interval.Error.AssertsMax,
                        => FloatError.AssertsMaxBits,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(
                err: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                switch (err) {
                    FloatError.InvalidArgument,
                    => info_validator.onError.?(err, prototype, actual),

                    FloatError.AssertsMinBits,
                    FloatError.AssertsMaxBits,
                    => bits_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).float.bits,
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test FloatError {
    _ = FloatError.InvalidArgument catch void;

    _ = FloatError.AssertsMinBits catch void;
    _ = FloatError.AssertsMaxBits catch void;
}

test Params {
    const params: Params = .{
        .bits = .{
            .min = null,
            .max = null,
        },
    };

    _ = params;
}

test init {
    const float: Prototype = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
    });

    _ = float;
}

test "evaluates float successfully" {
    const float = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(true, float.eval(f128));
}

test "coerces FloatError.InvalidArgument" {
    const float = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(
        FloatError.InvalidArgument,
        comptime float.eval(@as(f128, 0.0)),
    );
}

test "coerces FloatError.AssertsMinBits and FloatError.AssertsMaxBits" {
    const float = init(.{
        .bits = .{
            .min = 32,
            .max = 64,
        },
    });

    try std.testing.expectEqual(FloatError.AssertsMinBits, float.eval(f16));
    try std.testing.expectEqual(FloatError.AssertsMaxBits, float.eval(f128));
}
