//! Prototype *struct*.
//! 
//! Asserts *actual* is a struct type value with parametric layout, 
//! field, declaration, and tuple assertions.
//!
//! See also: [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");
const filter = @import("aux/filter.zig");
const field = @import("aux/field.zig");
const decl = @import("aux/decl.zig");
const toggle = @import("aux/toggle.zig");

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
    AssertsDecl,
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
pub const info_validator = info.init(.{
    .@"struct" = true,
});

/// Assertion parameters for *Layout* filter prototype.
///
/// See also:
/// `std.builtin.Type.Layout`
/// `LayoutParams`
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
const LayoutParams = struct {
    auto: ?bool = null,
    @"extern": ?bool = null,
    @"packed": ?bool = null,
};

/// *Layout* filter prototype.
///
/// See also:
/// `LayoutParams`
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
const Layout = filter.Filter(LayoutParams);

/// Assertion parameters for *struct* prototype.
///
/// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
pub const Params = struct {
    /// Asserts struct layout.
    ///
    /// See also:
    /// `std.builtin.Type.Layout`
    /// `Layout`
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    layout: LayoutParams = .{},
    /// Asserts struct fields.
    ///
    /// See also:
    /// - [`std.builtin.Type.StructField`](#std.builtin.Type.StructField)
    /// - [`ziggurat.prototype.aux.field`](#root.prototype.aux.field)
    fields: []const field.Params = &.{},
    /// Asserts struct declarations.
    ///
    /// See also:
    /// - [`std.builtin.Type.Declaration`](#std.builtin.Type.Declaration)
    /// - [`ziggurat.prototype.aux.decl`](#root.prototype.aux.decl)
    decls: []const decl.Params = &.{},
    /// Asserts struct tuple type.
    ///
    /// See also:
    /// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_tuple: ?bool = null,
};

pub fn init(params: Params) Prototype {
    const layout_validator = Layout.init(params.layout);
    const is_tuple_validator = toggle.init(params.is_tuple);
    return .{
        .name = "Struct",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => StructError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => StructError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = comptime layout_validator.eval(@typeInfo(actual).@"struct".layout) catch |err|
                    return switch (err) {
                        filter.Error.AssertsBlacklist,
                        => StructError.AssertsBlacklistLayout,
                        filter.Error.AssertsWhitelist,
                        => StructError.AssertsWhitelistLayout,
                        else => @panic("unhandled error"),
                    };

                inline for (params.fields) |param_field| {
                    const field_validator = field.init(param_field);
                    _ = field_validator.eval(actual) catch |err|
                        return switch (err) {
                            field.Error.AssertsField,
                            => StructError.AssertsStructField,
                            field.Error.AssertsBlacklistFieldTypeInfo,
                            => StructError.AssertsBlacklistStructFieldTypeInfo,
                            field.Error.AssertsWhitelistFieldTypeInfo,
                            => StructError.AssertsWhitelistStructFieldTypeInfo,
                            else => @panic("unhandled error"),
                        };
                }

                inline for (params.decls) |param_decl| {
                    const decl_validator = decl.init(param_decl);
                    _ = decl_validator.eval(actual) catch |err|
                        return switch (err) {
                            decl.Error.AssertsDecl,
                            => StructError.AssertsDecl,
                            else => @panic("unhandled error"),
                        };
                }

                _ = is_tuple_validator.eval(@typeInfo(actual).@"struct".is_tuple) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => StructError.AssertsTrueIsTuple,
                        toggle.Error.AssertsFalse,
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
                    => info_validator.onError.?(err, prototype, actual),

                    StructError.AssertsBlacklistLayout,
                    StructError.AssertsWhitelistLayout,
                    => layout_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).@"struct".layout,
                    ),

                    StructError.AssertsStructField,
                    StructError.AssertsBlacklistStructFieldTypeInfo,
                    StructError.AssertsWhitelistStructFieldTypeInfo,
                    => {
                        inline for (params.fields) |param_field| {
                            const field_validator = field.init(param_field);
                            _ = field_validator.eval(actual) catch
                                field_validator.onError.?(
                                    err,
                                    prototype,
                                    actual,
                                );
                        }
                    },

                    StructError.AssertsDeclName,
                    => {
                        inline for (params.decls) |param_decl| {
                            const decl_validator = field.init(param_decl);
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
                    => is_tuple_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).@"struct".is_tuple,
                    ),

                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => info_validator.onError.?(err, prototype, actual),

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
    _ = StructError.AssertsWhitelistStructFieldTypeInfo catch void;
    _ = StructError.AssertsBlacklistStructFieldTypeInfo catch void;
    _ = StructError.AssertsDecl catch void;
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
            .{ .name = "field", .type = .{ .bool = true } },
        },
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(
        StructError.AssertsStructField,
        @"struct".eval(struct { foo: bool }),
    );
}
test "fails struct field type info whitelist assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{
            .{
                .name = "field",
                .type = .{ .int = true },
            },
        },
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(
        StructError.AssertsWhitelistStructFieldTypeInfo,
        @"struct".eval(struct { field: bool }),
    );
}
test "fails struct field type info blacklist assertion" {
    const @"struct" = init(.{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{
            .{
                .name = "field",
                .type = .{ .bool = false },
            },
        },
        .decls = &.{},
        .is_tuple = null,
    });

    try std.testing.expectEqual(
        StructError.AssertsBlacklistStructFieldTypeInfo,
        @"struct".eval(struct { field: bool }),
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

    try std.testing.expectEqual(StructError.AssertsDecl, @"struct".eval(struct {
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
