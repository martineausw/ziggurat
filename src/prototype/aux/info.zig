//! Auxillary prototype for filtering type values based on active info tag.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const filter = @import("filter.zig");

const @"type" = @import("../type.zig");

/// Error set for info.
const InfoError = error{
    InvalidArgument,
    /// Violates type info blacklist assertion.
    BanishesType,
    /// Violates type info whitelist assertion.
    RequiresType,
};

/// Error set returned by `eval`.
pub const Error = InfoError;

const type_validator = @"type".init;

/// Parameters used for prototype evaluation.
///
/// Associated with `std.builtin.Type`.
///
/// For any field:
/// - `null`, no assertion.
/// - `true`, asserts active tag belongs to subset of `true` members.
/// - `false`, asserts active tag does not belong to subset of `false` members.
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

/// Expects type value.
///
/// `actual` is a type value, otherwise returns error from `IsType`.
///
/// `actual` active tag of `Type` belongs to the set of param fields set to
/// true, otherwise returns error.
///
/// `actual` active tag of `Type` does not belong to the set param fields
/// set to false, otherwise returns error.
pub fn init(params: Params) Prototype {
    const filter_validator = Filter.init(params);
    return .{
        .name = "Info",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime type_validator.eval(actual) catch |err|
                    return switch (err) {
                        @"type".Error.InvalidArgument => InfoError.InvalidArgument,
                        else => unreachable,
                    };

                _ = comptime filter_validator.eval(
                    @typeInfo(actual),
                ) catch |err|
                    return switch (err) {
                        filter.Error.Banishes => InfoError.BanishesType,
                        filter.Error.Requires => InfoError.RequiresType,
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
                    InfoError.InvalidArgument,
                    => type_validator.onError.?(err, prototype, actual),

                    InfoError.BanishesType,
                    InfoError.RequiresType,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: expect: {any}, actual: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params,
                            @tagName(@typeInfo(actual)),
                        },
                    )),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test InfoError {
    _ = InfoError.InvalidArgument catch void;
    _ = InfoError.BanishesType catch void;
    _ = InfoError.RequiresType catch void;
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

test "evaluates types against whitelist successfully" {
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

test "evaluates types against blacklist successfully" {
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

test "evaluates types against whitelist unsuccessfully" {
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
        Error.RequiresType,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime number.eval(f16),
    );

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime number.eval(comptime_int),
    );

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime number.eval(comptime_float),
    );
}

test "evaluates types against blacklist unsuccessfully" {
    const params: Params = .{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(usize),
    );

    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(u8),
    );

    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(i128),
    );

    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(f16),
    );
    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(f128),
    );

    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(comptime_int),
    );
    try std.testing.expectEqual(
        Error.BanishesType,
        comptime number.eval(comptime_float),
    );
}

test "evaluates invalid values" {
    const params: Params = .{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    };

    const number: Prototype = init(params);

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(usize, 0)),
    );

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(u8, 'a')),
    );

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(i128, 0)),
    );

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(f16, 0.0)),
    );

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(f128, 0.0)),
    );

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(comptime_int, 0)),
    );

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime number.eval(@as(comptime_float, 0.0)),
    );
}
