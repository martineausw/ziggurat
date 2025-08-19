//! Auxiliary prototype *info*.
//!
//! Asserts an *actual* type info active tag of a type value to respect
//! a given blacklist and/or whitelist.
//!
//! See also: [`std.builtin.Type`](#std.builtin.Type)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const filter = @import("filter.zig").Filter(std.builtin.Type);

const @"type" = @import("../type.zig");

/// Error set for *info* prototype.
const InfoError = error{
    /// `actual` is not a type value.
    ///
    /// See also: [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// `actual` type info has active tag that belongs to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistTypeInfo,
    /// `actual` type info has active tag that does not belong to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
};

pub const Error = InfoError;

/// Type value assertion for *info* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.type`](#root.prototype.type).
const type_validator = @"type".init;

/// Assertion parameters for *info* filter prototype.
///
/// For any field:
/// - *null*, no assertion.
/// - *true* asserts active tag belongs to subset of `true` members.
/// - *false* asserts active tag does not belong to subset of `false` members.
///
/// See also:
/// - [`std.builtin.Type`](#std.builtin.Type).
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter).
pub const Params = filter.Params;

pub fn init(params: filter.Params) Prototype {
    const filter_validator = filter.init(params);
    return .{
        .name = "Info",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = type_validator.eval(actual) catch |err|
                    return switch (err) {
                        @"type".Error.AssertsTypeValue => InfoError.AssertsTypeValue,
                        else => @panic("unhandled error"),
                    };

                _ = filter_validator.eval(
                    @typeInfo(actual),
                ) catch |err|
                    return switch (err) {
                        filter.Error.AssertsBlacklist => InfoError.AssertsBlacklistTypeInfo,
                        filter.Error.AssertsWhitelist => InfoError.AssertsWhitelistTypeInfo,
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
                    InfoError.AssertsTypeValue,
                    => comptime type_validator.onError.?(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: expect: {any}, actual: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params,
                            @typeName(actual),
                        },
                    )),
                }
            }
        }.onError,
    };
}

test InfoError {
    _ = InfoError.AssertsTypeValue catch void;
    _ = InfoError.AssertsBlacklistTypeInfo catch void;
    _ = InfoError.AssertsWhitelistTypeInfo catch void;
}

test Params {}

test init {}

test "passes whitelist assertions" {
    const params: Params = .{
        .int = true,
        .float = true,
        .comptime_int = true,
        .comptime_float = true,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(true, number.eval(usize));
    try std.testing.expectEqual(true, number.eval(u8));
    try std.testing.expectEqual(true, number.eval(i128));

    try std.testing.expectEqual(true, number.eval(f16));
    try std.testing.expectEqual(true, number.eval(f128));

    try std.testing.expectEqual(true, number.eval(comptime_int));
    try std.testing.expectEqual(true, number.eval(comptime_float));
}

test "passes blacklist assertions" {
    const params: Params = .{
        .type = false,
        .void = false,
        .bool = false,
        .noreturn = false,
        .pointer = false,
        .array = false,
        .@"struct" = false,
        .undefined = false,
        .null = false,
        .optional = false,
        .error_union = false,
        .error_set = false,
        .@"enum" = false,
        .@"union" = false,
        .@"fn" = false,
        .@"opaque" = false,
        .frame = false,
        .@"anyframe" = false,
        .vector = false,
        .enum_literal = false,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        true,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        true,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        true,
        comptime number.eval(f16),
    );
    try std.testing.expectEqual(
        true,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        true,
        comptime number.eval(comptime_int),
    );

    try std.testing.expectEqual(
        true,
        comptime number.eval(comptime_float),
    );
}

test "fails whitelist assertions" {
    const params: Params = .{
        .type = true,
        .void = true,
        .bool = true,
        .noreturn = true,
        .pointer = true,
        .array = true,
        .@"struct" = true,
        .undefined = true,
        .null = true,
        .optional = true,
        .error_union = true,
        .error_set = true,
        .@"enum" = true,
        .@"union" = true,
        .@"fn" = true,
        .@"opaque" = true,
        .frame = true,
        .@"anyframe" = true,
        .vector = true,
        .enum_literal = true,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(f16),
    );

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(comptime_int),
    );

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime number.eval(comptime_float),
    );
}

test "fails blacklist assertions" {
    const params: Params = .{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(f16),
    );
    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(comptime_int),
    );
    try std.testing.expectEqual(
        Error.AssertsBlacklistTypeInfo,
        comptime number.eval(comptime_float),
    );
}

test "fails argument assertions" {
    const params: Params = .{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(usize, 0)),
    );

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(u8, 'a')),
    );

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(i128, 0)),
    );

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(f16, 0.0)),
    );

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(f128, 0.0)),
    );

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(comptime_int, 0)),
    );

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime number.eval(@as(comptime_float, 0.0)),
    );
}
