//! Auxiliary prototype interval.
//!
//! Asserts an *actual* integer or float to be within a given inclusive interval.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("FiltersTypeInfo.zig");

/// Error set for interval.
const WithinIntervalError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires int, float, comptime_int, or comptime_float type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* value is less than minimum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMin,
    /// *actual* value is greater than maximum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMax,
};

pub const Error = WithinIntervalError;

/// Type value assertion for *interval* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.type`](#root.prototype.type)
pub const has_type_info = FiltersTypeInfo.init(.{
    .int = true,
    .float = true,
    .comptime_int = true,
    .comptime_float = true,
});

/// Assertion parameters for *interval* prototype.
pub const Params = struct {
    /// Asserts value is greater than or equal to minimum.
    min: ?f128 = null,
    /// Asserts value is less than or equal to maximum.
    max: ?f128 = null,
    /// Asserts equality of bounds is within tolerance margin.
    tolerance: ?f128 = null,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(@This()),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => WithinIntervalError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => WithinIntervalError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                const tolerance = params.tolerance orelse std.math.floatEps(f128);
                const min = params.min orelse std.math.floatMin(f128);
                const max = params.max orelse std.math.floatMax(f128);

                const value = switch (@typeInfo(@TypeOf(actual))) {
                    .comptime_int, .int => @as(f128, @floatFromInt(actual)),
                    .comptime_float, .float => @as(f128, @floatCast(actual)),
                    else => unreachable,
                };

                if (!std.math.approxEqAbs(f128, min, value, tolerance) and min > value) {
                    return WithinIntervalError.AssertsMin;
                }

                if (!std.math.approxEqAbs(f128, max, value, tolerance) and max < value) {
                    return WithinIntervalError.AssertsMax;
                }

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
                    WithinIntervalError.AssertsTypeValue,
                    WithinIntervalError.AssertsWhitelistTypeInfo,
                    => comptime has_type_info.onError.?(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {d}",
                        .{
                            prototype.name,
                            @errorName(err),
                            actual,
                        },
                    )),
                }
            }
        }.onError,
    };
}

test WithinIntervalError {
    _ = WithinIntervalError.AssertsTypeValue catch void;
    _ = WithinIntervalError.AssertsWhitelistTypeInfo catch void;
    _ = WithinIntervalError.AssertsMin catch void;
    _ = WithinIntervalError.AssertsMax catch void;
}

test Params {
    const params: Params = .{
        .min = null,
        .max = null,
    };

    _ = params;
}

test init {
    const interval: Prototype = init(.{
        .min = null,
        .max = null,
    });

    _ = interval;
}

test "passes interval assertions on runtime int values" {
    const usize_interval = init(.{
        .min = 0,
        .max = 2,
    });

    try std.testing.expectEqual(true, usize_interval.eval(@as(usize, 0)));
    try std.testing.expectEqual(true, usize_interval.eval(@as(usize, 1)));
    try std.testing.expectEqual(true, usize_interval.eval(@as(usize, 2)));

    const i128_interval = init(.{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(true, i128_interval.eval(@as(i128, -1)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(i128, 0)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(i128, 1)));
}

test "passes interval assertions on runtime float values" {
    const f16_interval = init(.{
        .min = -1.0,
        .max = 1.0,
    });

    try std.testing.expectEqual(true, f16_interval.eval(@as(f16, -1.0)));
    try std.testing.expectEqual(true, f16_interval.eval(@as(f16, 0.0)));
    try std.testing.expectEqual(true, f16_interval.eval(@as(f16, 1.0)));

    const i128_interval = init(.{
        .min = -1.0,
        .max = 1.0,
    });

    try std.testing.expectEqual(true, i128_interval.eval(@as(f128, -1)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(f128, 0)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(f128, 1)));
}

test "passes interval assertions on comptime_int values" {
    const interval = init(.{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_int, -1)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_int, 0)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_int, 1)),
    );
}

test "passes interval assertions on comptime_float values" {
    const interval = init(.{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_float, -1)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_float, 0)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_float, 1)),
    );
}

test "fails inclusive minimum assertion" {
    const interval = init(.{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        WithinIntervalError.AssertsMin,
        interval.eval(@as(comptime_float, -1.001)),
    );
}

test "fails inclusive maximum assertion" {
    const interval = init(.{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        WithinIntervalError.AssertsMax,
        interval.eval(@as(comptime_float, 1.001)),
    );
}
