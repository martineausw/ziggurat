//! Prototype *float*.
//!
//! Asserts *actual* is a float type value with a parametric bits
//! assertion.
//!
//! See also: [`std.builtin.Type.Float`](#std.builtin.Type.Float)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");

const WithinInterval = @import("aux/WithinInterval.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");

/// Error set for *float* prototype.
const FloatError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires float type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* float bits value is less than minimum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMinBits,
    /// *actual* float bits value is greater than maximum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMaxBits,
};

pub const Error = FloatError;

/// Type value assertion for *float* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .float = true,
});

/// Assertion parameters for *float* prototype.
///
/// - [`std.builtin.Type.Float`](#std.builtin.Type.Float)
pub const Params = struct {
    /// Asserts float bits interval.
    ///
    /// See also:
    /// - [`std.builtin.Type.Float`](#std.builtin.Type.Float)
    /// - [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    bits: WithinInterval.Params = .{},
};

pub fn init(params: Params) Prototype {
    const bits = WithinInterval.init(params.bits);

    return .{
        .name = "Float",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => FloatError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => FloatError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = bits.eval(@typeInfo(actual).float.bits) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin,
                        => FloatError.AssertsMinBits,
                        WithinInterval.Error.AssertsMax,
                        => FloatError.AssertsMaxBits,
                        else => @panic("unhandled error"),
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
                    FloatError.AssertsTypeValue,
                    => has_type_info.onError.?(err, prototype, actual),

                    FloatError.AssertsMinBits,
                    FloatError.AssertsMaxBits,
                    => bits.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).float.bits,
                    ),

                    else => @panic("unhandled error"),
                }
            }
        }.onError,
    };
}

test FloatError {
    _ = FloatError.AssertsTypeValue catch void;
    _ = FloatError.AssertsWhitelistTypeInfo catch void;

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

test "passes float assertions" {
    const float = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(true, float.eval(f128));
}

test "fails type value assertion" {
    const float = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(
        FloatError.AssertsTypeValue,
        comptime float.eval(@as(f128, 0.0)),
    );
}

test "fails float bits interval assertions" {
    const float = init(.{
        .bits = .{
            .min = 32,
            .max = 64,
        },
    });

    try std.testing.expectEqual(FloatError.AssertsMinBits, float.eval(f16));
    try std.testing.expectEqual(FloatError.AssertsMaxBits, float.eval(f128));
}
