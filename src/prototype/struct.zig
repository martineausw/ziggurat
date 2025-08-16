//! Prototype for `type` value with struct type info.
//!
//! `eval` asserts array type within parameters:
//!
//! - `child`, type info filter assertion.
//! - `len`, type info interval assertion.
//! - `sentinel`, type info value assertion.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");
const filter = @import("aux/filter.zig");
const field = @import("aux/field.zig");
const decl = @import("aux/decl.zig");
const toggle = @import("aux/toggle.zig");

/// Error set for array.
const StructError = error{
    InvalidArgument,
    RequiresTypeInfo,
    BanishesLayout,
    RequiresLayout,
    AssertsStructField,
    RequiresStructFieldTypeInfo,
    BanishesStructFieldTypeInfo,
    AssertsDecl,
    AssertsTrueIsTuple,
    AssertsFalseIsTuple,
};

/// Error set returned by `eval`
pub const Error = StructError;

pub const info_validator = info.init(.{
    .@"struct" = true,
});

const LayoutParams = struct {
    auto: ?bool = null,
    @"extern": ?bool = null,
    @"packed": ?bool = null,
};

const Layout = filter.Filter(LayoutParams);
/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Struct`.
pub const Params = struct {
    layout: LayoutParams = .{},
    fields: []const field.Params = &.{},
    decls: []const decl.Params = &.{},
    is_tuple: ?bool = null,
};

/// Expects array type value.
///
/// `actual` is an array type value.
///
/// `actual` type info `len` is within given `params`.
///
/// `actual` type info `sentinel()` is not-null when given params is true
/// or null when given params is false, otherwise returns error.
pub fn init(params: Params) Prototype {
    const layout_validator = Layout.init(params.layout);
    const is_tuple_validator = toggle.init(params.is_tuple);
    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        => StructError.InvalidArgument,
                        info.Error.RequiresTypeInfo,
                        => StructError.RequiresTypeInfo,
                        else => unreachable,
                    };

                _ = comptime layout_validator.eval(@typeInfo(actual).@"struct".layout) catch |err|
                    return switch (err) {
                        filter.Error.Banishes,
                        => StructError.BanishesLayout,
                        filter.Error.Requires,
                        => StructError.RequiresLayout,
                        else => unreachable,
                    };

                inline for (params.fields) |param_field| {
                    const field_validator = field.init(param_field);
                    _ = field_validator.eval(actual) catch |err|
                        return switch (err) {
                            field.Error.AssertsField,
                            => StructError.AssertsStructField,
                            field.Error.BanishesFieldTypeInfo,
                            => StructError.BanishesStructFieldTypeInfo,
                            field.Error.RequiresFieldTypeInfo,
                            => StructError.RequiresStructFieldTypeInfo,
                            else => unreachable,
                        };
                }

                inline for (params.decls) |param_decl| {
                    const decl_validator = decl.init(param_decl);
                    _ = decl_validator.eval(actual) catch |err|
                        return switch (err) {
                            decl.Error.AssertsDecl,
                            => StructError.AssertsDecl,
                            else => unreachable,
                        };
                }

                _ = is_tuple_validator.eval(@typeInfo(actual).@"struct".is_tuple) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => StructError.AssertsTrueIsTuple,
                        toggle.Error.AssertsFalse,
                        => StructError.AssertsFalseIsTuple,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    StructError.InvalidArgument,
                    => info_validator.onError.?(err, prototype, actual),

                    StructError.BanishesLayout,
                    StructError.RequiresLayout,
                    => layout_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).@"struct".layout,
                    ),

                    StructError.AssertsStructField,
                    StructError.BanishesStructFieldTypeInfo,
                    StructError.RequiresStructFieldTypeInfo,
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

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test StructError {
    _ = StructError.InvalidArgument catch void;

    _ = StructError.BanishesLayout catch void;
    _ = StructError.RequiresLayout catch void;

    _ = StructError.AssertsStructField catch void;
    _ = StructError.RequiresStructFieldTypeInfo catch void;
    _ = StructError.BanishesStructFieldTypeInfo catch void;

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

test "evaluates struct successfully" {
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

test "coerces StructError.BanishesLayout" {
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

    try std.testing.expectEqual(StructError.BanishesLayout, comptime @"struct".eval(packed struct {}));
}

test "coerces StructError.RequiresLayout" {
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

    try std.testing.expectEqual(StructError.RequiresLayout, comptime @"struct".eval(packed struct {}));
}

test "coerces StructError.AssertsStructFieldName" {
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
test "coerces StructError.RequiresStructFieldType" {
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
        StructError.RequiresStructFieldTypeInfo,
        @"struct".eval(struct { field: bool }),
    );
}
test "coerces StructError.BanishesStructFieldType" {
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
        StructError.BanishesStructFieldTypeInfo,
        @"struct".eval(struct { field: bool }),
    );
}
test "coerces StructError.AssertsDeclName" {
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
test "coerces StructError.AssertsTrueIsTuple" {
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

test "coerces StructError.AssertsFalseIsTuple" {
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
