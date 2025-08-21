//! Auxiliary prototype that checks a type for a field.
//!
//! Asserts an *actual* struct or union type value to have a field of type
//! and optionally respect a type info whitelist and/or blacklist.
//!
//! See also:
//! - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
//! - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("FiltersTypeInfo.zig");
const OnType = @import("OnType.zig");

const Self = @This();

/// Error set for *field* prototype.
const HasFieldError = error{
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
    AssertsHasField,
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

pub const Error = HasFieldError;

/// Type info assertions for *field* prototype evaluation argument.
///
/// See also:
/// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
/// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
/// - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
pub const has_type_info = FiltersTypeInfo.init(.{
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
    type: OnType.Params,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => HasFieldError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => HasFieldError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (!@hasField(actual, params.name)) {
                    return HasFieldError.AssertsHasField;
                }

                _ = try OnType.init(params.type).eval(@FieldType(
                    actual,
                    params.name,
                ));

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
                    HasFieldError.AssertsTypeValue,
                    HasFieldError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

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

test HasFieldError {
    _ = HasFieldError.AssertsTypeValue catch void;
    _ = HasFieldError.AssertsHasField catch void;
}

test Params {
    const T = struct {
        field: f128,
    };

    _ = T;

    const params: Params = .{
        .name = "field",
        .type = .true,
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
        .type = .true,
    });

    _ = field;
}

test "passes field assertions on struct" {
    const T = struct {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .true
    };

    const HasField: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        HasField.eval(T),
    );
}

test "passes field assertions on union" {
    const T = union {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .true,
    };

    const HasField: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        HasField.eval(T),
    );
}

test "fails field assertion on struct" {
    const T = struct {};

    const params: Params = .{
        .name = "field",
        .type = .true,
    };

    const HasField: Prototype = init(params);

    try std.testing.expectEqual(
        HasFieldError.AssertsHasField,
        HasField.eval(T),
    );
}
