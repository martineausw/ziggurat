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
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => FloatError.InvalidArgument,
                        else => unreachable,
                    };

                const actual_info = switch (@typeInfo(actual)) {
                    .float => |float_info| float_info,
                    else => unreachable,
                };

                _ = bits_validator.eval(actual_info.bits) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin => FloatError.AssertsMinBits,
                        interval.Error.AssertsMax => FloatError.AssertsMaxBits,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    FloatError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

                    FloatError.AssertsMinBits,
                    FloatError.AssertsMaxBits,
                    => bits_validator.onError(err, prototype, @typeInfo(actual).float.bits),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.ExceedsMin catch void;
    _ = Error.ExceedsMax catch void;
}

test info_validator {
    _ = try info_validator.eval(bool);
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
    const float32 = init(.{
        .bits = .{
            .min = 32,
            .max = 32,
        },
    });

    try testing.expectEqual(Error.ExceedsMin, float32.eval(f16));
    try testing.expectEqual(true, float32.eval(f32));
    try testing.expectEqual(Error.ExceedsMax, float32.eval(f128));
}
