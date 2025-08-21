//! Prototype *int*.
//!
//! Asserts *actual* is an integer type value with parametric bits
//! and signedness assertions.
//!
//! See also: [`std.builtin.Type.Int`](#std.builtin.Type.Int)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const FiltersActiveTag = @import("aux/FiltersActiveTag.zig");

const Self = @This();

/// Error set for *int* prototype.
const IntError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires int type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* int bits value is less than minimum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMinBits,
    /// *actual* int bits value is greater than maximum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMaxBits,
    /// *actual* int signedness has active tag that belongs to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistSignedness,
    /// *actual* int signedness has active tag that does not belong to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistSignedness,
};

pub const Error = IntError;

/// Type value assertion for *int* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .int = true,
});

/// *Signedness* prototype.
///
/// See also:
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
const FiltersSignedness = FiltersActiveTag.Of(std.builtin.Signedness);

/// Assertion parameters for *int* prototype.
///
/// See also: [`std.builtin.Type.Int`](#std.builtin.Type.Int)
pub const Params = struct {
    /// Asserts int bits interval.
    ///
    /// See also:
    /// - [`std.builtin.Type.Int`](#std.builtin.Type.Int)
    /// - [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    bits: WithinInterval.Params = .{},
    /// Asserts int signedness.
    ///
    /// See also:
    /// - [`std.builtin.Type.Int`](#std.builtin.Type.Int)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    signedness: FiltersSignedness.Params = .{},
};

pub fn init(params: Params) Prototype {
    const bits = WithinInterval.init(params.bits);
    const signedness = FiltersSignedness.init(params.signedness);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => IntError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => IntError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = bits.eval(@typeInfo(actual).int.bits) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin => IntError.AssertsMinBits,
                        WithinInterval.Error.AssertsMax => IntError.AssertsMaxBits,
                        else => @panic("unhandled error"),
                    };

                _ = comptime signedness.eval(
                    @typeInfo(actual).int.signedness,
                ) catch |err|
                    return switch (err) {
                        FiltersSignedness.Error.AssertsBlacklist => IntError.AssertsBlacklistSignedness,
                        FiltersSignedness.Error.AssertsWhitelist => IntError.AssertsWhitelistSignedness,
                        else => @panic("unhandled error"),
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    IntError.AssertsTypeValue,
                    IntError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    IntError.AssertsMinBits,
                    IntError.AssertsMaxBits,
                    => bits.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).int.bits,
                    ),

                    IntError.AssertsBlacklistSignedness,
                    IntError.AssertsWhitelistSignedness,
                    => signedness.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).int.signedness,
                    ),

                    else => @panic("unhandled error"),
                }
            }
        }.onError,
    };
}

test IntError {
    _ = IntError.AssertsTypeValue catch void;
    _ = IntError.AssertsMinBits catch void;
    _ = IntError.AssertsMaxBits catch void;
    _ = IntError.AssertsBlacklistSignedness catch void;
    _ = IntError.AssertsWhitelistSignedness catch void;
}

test Params {
    const params: Params = .{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .signed = null,
            .unsigned = null,
        },
    };

    _ = params;
}

test init {
    const int: Prototype = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .signed = null,
            .unsigned = null,
        },
    });

    _ = int;
}

test "passes int assertions" {
    const int = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{},
    });

    try std.testing.expectEqual(true, int.eval(i128));
    try std.testing.expectEqual(true, int.eval(usize));
}

test "fails type value assertion" {
    const int = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{},
    });

    try std.testing.expectEqual(
        IntError.AssertsTypeValue,
        comptime int.eval(@as(i128, 0)),
    );
}

test "fails int bits interval assertions" {
    const int = init(.{
        .bits = .{
            .min = 32,
            .max = 64,
        },
        .signedness = .{},
    });

    try std.testing.expectEqual(IntError.AssertsMinBits, comptime int.eval(i16));
    try std.testing.expectEqual(IntError.AssertsMaxBits, comptime int.eval(i128));
}

test "fails int signedness blacklist assertion" {
    const int = init(.{ .bits = .{
        .min = null,
        .max = null,
    }, .signedness = .{
        .signed = false,
    } });

    try std.testing.expectEqual(IntError.AssertsBlacklistSignedness, comptime int.eval(i128));
}

test "fails int signedness whitelist assertion" {
    const int = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .unsigned = true,
        },
    });

    try std.testing.expectEqual(IntError.AssertsWhitelistSignedness, comptime int.eval(i128));
}
