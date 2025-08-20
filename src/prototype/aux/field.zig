//! Auxiliary prototype *field*.
//!
//! Asserts an *actual* struct or union type value to have a field of type
//! and optionally respect a type info whitelist and/or blacklist.
//!
//! See also:
//! - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
//! - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");
const info_switch = @import("info_switch.zig");

/// Error set for *field* prototype.
const FieldError = error{
    /// `actual` is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// `actual` requires struct or union type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// `actual` is missing field.
    AssertsField,
    /// `actual` has field with type info that belongs to blacklist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistFieldTypeInfo,
    /// `actual` has field with type info that does not belong to whitelist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistFieldTypeInfo,
};

pub const Error = FieldError;

/// Type info assertions for *field* prototype evaluation argument.
///
/// See also:
/// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
/// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
/// - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
pub const info_validator = info.init(.{
    .@"struct" = true,
    .@"union" = true,
});

/// Parameters used for prototype evaluation.
///
/// See also:
/// - [`std.builtin.Type.StructField`](#std.builtin.Type.StructField)
/// - [`std.builtin.Type.UnionField`](#std.builtin.Type.UnionField)
pub const Params = struct {
    /// Asserts struct field.
    ///
    /// See also:
    /// - [`std.builtin.Type.StructField`](#std.builtin.Type.StructField)
    /// - [`std.builtin.Type.UnionField`](#std.builtin.Type.UnionField)
    name: [:0]const u8,
    /// Asserts struct field type.
    ///
    /// See also:
    /// - [`std.builtin.Type.StructField`](#std.builtin.Type.StructField)
    /// - [`std.builtin.Type.UnionField`](#std.builtin.Type.UnionField)
    type: info_switch.Params,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = "Field",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => FieldError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => FieldError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (!@hasField(actual, params.name)) {
                    return FieldError.AssertsField;
                }

                _ = info_switch.init(params.type).eval(@FieldType(
                    actual,
                    params.name,
                )) catch |err|
                    return switch (err) {
                        info.Error.AssertsBlacklistTypeInfo => FieldError.AssertsBlacklistFieldTypeInfo,
                        info.Error.AssertsWhitelistTypeInfo => FieldError.AssertsWhitelistFieldTypeInfo,
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
                    FieldError.AssertsTypeValue,
                    FieldError.AssertsWhitelistTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}: ",
                        .{
                            prototype.name,
                            @errorName(err),
                            params.name,
                            @FieldType(actual, params.name),
                        },
                    )),
                }
            }
        }.onError,
    };
}

test FieldError {
    _ = FieldError.AssertsTypeValue catch void;
    _ = FieldError.AssertsField catch void;
    _ = FieldError.AssertsBlacklistFieldTypeInfo catch void;
}

test Params {
    const T = struct {
        field: f128,
    };

    _ = T;

    const params: Params = .{
        .name = "field",
        .type = .{
            .float = .true,
        },
    };

    _ = params;
}

test init {
    const T = struct {
        field: f128,
    };

    _ = T;

    const field: Prototype = init(.{
        .name = "field",
        .type = .{
            .float = .true,
        },
    });

    _ = field;
}

test "passes field assertions on struct" {
    const T = struct {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = .true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_field.eval(T),
    );
}

test "passes field assertions on union" {
    const T = union {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = .true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_field.eval(T),
    );
}

test "fails field assertion on struct" {
    const T = struct {};

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = .true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        FieldError.AssertsField,
        has_field.eval(T),
    );
}

test "fails field type info whitelist assertion on struct" {
    const T = struct {
        field: ?bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = .true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        FieldError.AssertsWhitelistFieldTypeInfo,
        comptime has_field.eval(T),
    );
}

test "fails field type info blacklist assertion on struct" {
    const T = struct {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = .false,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        FieldError.AssertsBlacklistFieldTypeInfo,
        comptime has_field.eval(T),
    );
}
