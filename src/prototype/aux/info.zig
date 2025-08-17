//! Evaluates the *active tag* of a type value's type info against a 
//! *blacklist* and/or *whitelist*.
//! 
//! See also: [`std.builtin.Type`](#std.builtin.Type)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const filter = @import("filter.zig");

const @"type" = @import("../type.zig");

/// Error set for *info* prototype.
const InfoError = error{
    /// `actual` is not a type value.
    /// 
    /// See also: [`ziggurat.prototype.type`](#root.prototype.type)
    ExpectsTypeValue,
    /// `actual` type info has active tag that belongs to blacklist.
    /// 
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    BanishesTypeInfo,
    /// `actual` type info has active tag that does not belong to whitelist.
    /// 
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    RequiresTypeInfo,

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
pub const Params = struct {
    type: ?bool = null,
    void: ?bool = null,
    bool: ?bool = null,
    noreturn: ?bool = null,
    int: ?bool = null,
    float: ?bool = null,
    pointer: ?bool = null,
    array: ?bool = null,
    @"struct": ?bool = null,
    comptime_float: ?bool = null,
    comptime_int: ?bool = null,
    undefined: ?bool = null,
    null: ?bool = null,
    optional: ?bool = null,
    error_union: ?bool = null,
    error_set: ?bool = null,
    @"enum": ?bool = null,
    @"union": ?bool = null,
    @"fn": ?bool = null,
    @"opaque": ?bool = null,
    frame: ?bool = null,
    @"anyframe": ?bool = null,
    vector: ?bool = null,
    enum_literal: ?bool = null,
};

const Filter = filter.Filter(Params);

pub fn init(params: Params) Prototype {
    const filter_validator = Filter.init(params);
    return .{
        .name = "Info",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = type_validator.eval(actual) catch |err|
                    return switch (err) {
                        @"type".Error.ExpectsTypeValue => InfoError.ExpectsTypeValue,
                        else => unreachable,
                    };

                _ = filter_validator.eval(
                    @typeInfo(actual),
                ) catch |err|
                    return switch (err) {
                        filter.Error.Banishes => InfoError.BanishesTypeInfo,
                        filter.Error.Requires => InfoError.RequiresTypeInfo,
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
                    InfoError.ExpectsTypeValue,
                    => type_validator.onError.?(err, prototype, actual),

                    InfoError.BanishesTypeInfo,
                    InfoError.RequiresTypeInfo,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: expect: {any}, actual: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params,
                            @typeName(@typeInfo(actual)),
                        },
                    )),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test InfoError {
    _ = InfoError.ExpectsTypeValue catch void;
    _ = InfoError.BanishesTypeInfo catch void;
    _ = InfoError.RequiresTypeInfo catch void;
}

test Params {
    const params: Params = .{
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
    };

    _ = params;
}

test init {
    const info: Prototype = init(.{
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

    _ = info;
}

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
        Error.RequiresTypeInfo,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        Error.RequiresTypeInfo,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        Error.RequiresTypeInfo,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        Error.RequiresTypeInfo,
        comptime number.eval(f16),
    );

    try std.testing.expectEqual(
        Error.RequiresTypeInfo,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        Error.RequiresTypeInfo,
        comptime number.eval(comptime_int),
    );

    try std.testing.expectEqual(
        Error.RequiresTypeInfo,
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
        Error.BanishesTypeInfo,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        Error.BanishesTypeInfo,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        Error.BanishesTypeInfo,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        Error.BanishesTypeInfo,
        comptime number.eval(f16),
    );
    try std.testing.expectEqual(
        Error.BanishesTypeInfo,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        Error.BanishesTypeInfo,
        comptime number.eval(comptime_int),
    );
    try std.testing.expectEqual(
        Error.BanishesTypeInfo,
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
        Error.ExpectsTypeValue,
        comptime number.eval(@as(usize, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        comptime number.eval(@as(u8, 'a')),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        comptime number.eval(@as(i128, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        comptime number.eval(@as(f16, 0.0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        comptime number.eval(@as(f128, 0.0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        comptime number.eval(@as(comptime_int, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        comptime number.eval(@as(comptime_float, 0.0)),
    );
}
