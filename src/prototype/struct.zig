//! Prototype *struct*.
//!
//! Asserts *actual* is a struct type value with parametric layout,
//! field, declaration, and tuple assertions.
//!
//! See also: [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const FiltersActiveTag = @import("aux/FiltersActiveTag.zig");
const HasField = @import("aux/HasField.zig");
const HasDecl = @import("aux/HasDecl.zig");
const EqualsBool = @import("aux/EqualsBool.zig");

const Self = @This();

/// Error set for *struct* prototype.
const StructError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires struct type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* struct layout has active tag that belongs to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistLayout,
    /// *actual* struct layout has active tag that does not belong to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistLayout,
    /// *actual* struct is missing field.
    ///
    /// See also: [`ziggurat.prototype.aux.field`](#root.prototype.aux.field)
    AssertsStructField,
    /// *actual* struct field type info has active tag that does not belong to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistStructFieldTypeInfo,
    /// *actual* struct field type info has active tag that belongs to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistStructFieldTypeInfo,
    /// *actual* struct is missing declaration.
    ///
    /// See also: [`ziggurat.prototype.aux.decl`](#root.prototype.aux.decl)
    AssertsHasDecl,
    /// *actual* struct is not a tuple.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsTrueIsTuple,
    /// *actual* struct is a tuple.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsFalseIsTuple,
};

pub const Error = StructError;

/// Type value assertion for *struct* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .@"struct" = true,
});

/// *Layout* filter prototype.
///
/// See also:
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
const FiltersLayout = FiltersActiveTag.Of(std.builtin.Type.ContainerLayout);

/// Assertion parameters for *struct* prototype.
///
/// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
pub const Params = struct {
    /// Asserts struct layout.
    ///
    /// See also:
    /// - [`std.builtin.Type.ContainerLayout`](#std.builtin.Type.ContainerLayout)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    layout: FiltersLayout.Params = .{},
    /// Asserts struct fields.
    ///
    /// See also:
    /// - [`std.builtin.Type.StructField`](#std.builtin.Type.StructField)
    /// - [`ziggurat.prototype.aux.field`](#root.prototype.aux.field)
    fields: []const HasField.Params = &.{},
    /// Asserts struct declarations.
    ///
    /// See also:
    /// - [`std.builtin.Type.Declaration`](#std.builtin.Type.Declaration)
    /// - [`ziggurat.prototype.aux.decl`](#root.prototype.aux.decl)
    decls: []const HasDecl.Params = &.{},
    /// Asserts struct tuple type.
    ///
    /// See also:
    /// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_tuple: ?bool = null,
};

pub fn init(params: Params) Prototype {
    const layout = FiltersLayout.init(params.layout);
    const is_tuple = EqualsBool.init(params.is_tuple);
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => StructError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => StructError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = comptime layout.eval(@typeInfo(actual).@"struct".layout) catch |err|
                    return switch (err) {
                        FiltersLayout.Error.AssertsBlacklist,
                        => StructError.AssertsBlacklistLayout,
                        FiltersLayout.Error.AssertsWhitelist,
                        => StructError.AssertsWhitelistLayout,
                        else => @panic("unhandled error"),
                    };

                inline for (params.fields) |param_field| {
                    const field_validator = HasField.init(param_field);
                    _ = field_validator.eval(actual) catch |err|
                        return switch (err) {
                            HasField.Error.AssertsHasField,
                            => StructError.AssertsStructField,

                            else => @panic("unhandled error"),
                        };
                }

                inline for (params.decls) |param_decl| {
                    const decl_validator = HasDecl.init(param_decl);
                    _ = decl_validator.eval(actual) catch |err|
                        return switch (err) {
                            HasDecl.Error.AssertsHasDecl,
                            => StructError.AssertsHasDecl,
                            else => @panic("unhandled error"),
                        };
                }

                _ = is_tuple.eval(@typeInfo(actual).@"struct".is_tuple) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => StructError.AssertsTrueIsTuple,
                        EqualsBool.Error.AssertsFalse,
                        => StructError.AssertsFalseIsTuple,
                        else => @panic("unhandled error"),
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    StructError.AssertsTypeValue,
                    => has_type_info.onError.?(err, prototype, actual),

                    StructError.AssertsBlacklistLayout,
                    StructError.AssertsWhitelistLayout,
                    => layout.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).@"struct".layout,
                    ),

                    StructError.AssertsStructField,
                    => {
                        inline for (params.fields) |param_field| {
                            const field_validator = HasField.init(param_field);
                            _ = field_validator.eval(actual) catch
                                field_validator.onError.?(
                                    err,
                                    prototype,
                                    actual,
                                );
                        }
                    },

                    StructError.AssertsHasDeclName,
                    => {
                        inline for (params.decls) |param_decl| {
                            const decl_validator = HasField.init(param_decl);
                            _ = decl_validator.eval(actual) catch
                                decl_validator.onError.?(
                                    err,
                                    prototype,
                                    actual,
                                );
                        }
                    },

                    StructError.AssertsTrueIsTuple,
                    StructError.AssertsFalseIsTuple,
                    => is_tuple.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).@"struct".is_tuple,
                    ),

                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => has_type_info.onError.?(err, prototype, actual),

                    else => @panic("unhandled error"),
                }
            }
        }.onError,
    };
}

test StructError {
    _ = StructError.AssertsTypeValue catch void;
    _ = StructError.AssertsWhitelistTypeInfo catch void;
    _ = StructError.AssertsBlacklistLayout catch void;
    _ = StructError.AssertsWhitelistLayout catch void;
    _ = StructError.AssertsStructField catch void;
    _ = StructError.AssertsHasDecl catch void;
    _ = StructError.AssertsTrueIsTuple catch void;
    _ = StructError.AssertsFalseIsTuple catch void;
}

test Params {
    const params: Params = .{
        .layout = .{
            .auto = null,
            .@"packed" = null,
            .@"extern" = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    };

    _ = params;
}

test init {
    const @"struct" = init(.{
        .layout = .{
            .auto = null,
            .@"packed" = null,
            .@"extern" = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    });

    _ = @"struct";
}

test "passes struct assertions" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(true, @"struct".eval(struct {}));
}

test "fails struct layout blacklist assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = false,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(StructError.AssertsBlacklistLayout, comptime @"struct".eval(packed struct {}));
}

test "fails struct layout whitelist assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = true,
            .@"packed" = null,
            .auto = true,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(StructError.AssertsWhitelistLayout, comptime @"struct".eval(packed struct {}));
}

test "fails struct field assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{
            .{ .name = "field", .type = .true },
        },
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(
        StructError.AssertsStructField,
        @"struct".eval(struct { foo: bool }),
    );
}

test "fails struct declaration assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{.{ .name = "decl" }},
        .is_tuple = null,
    });

    try std.testing.expectEqual(StructError.AssertsHasDecl, @"struct".eval(struct {
        const decl = 0;
    }));
}
test "fails struct is tuple assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = true,
    });

    try std.testing.expectEqual(StructError.AssertsTrueIsTuple, @"struct".eval(struct {}));
}

test "fails struct is not tuple assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = false,
    });

    try std.testing.expectEqual(StructError.AssertsFalseIsTuple, @"struct".eval(struct { bool, bool, comptime_int }));
}
