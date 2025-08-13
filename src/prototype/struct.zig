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
    BanishesLayout,
    RequiresLayout,
    AssertsStructFieldName,
    BanishesStructFieldType,
    AssertsDeclName,
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
    fields: []const field.Params = .{},
    decls: []const decl.Params = .{},
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
                _ = try info_validator.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .@"struct" => |struct_info| struct_info,
                    else => unreachable,
                };

                _ = layout_validator.eval(actual_info.layout) catch |err| return switch (err) {
                    filter.Error.Disallowed => StructError.BanishesLayout,
                    filter.Error.Unexpected => StructError.RequiresLayout,
                    else => unreachable,
                };

                inline for (params.fields) |param_field| {
                    const field_validator = field.init(param_field);
                    _ = field_validator.eval(actual) catch |err|
                        return switch (err) {
                            field.Error.AssertsFieldName => StructError.AssertsStructFieldName,
                            field.Error.BanishesFieldType => StructError.BanishesStructFieldType,
                            field.Error.RequiresFieldType => StructError.RequiresStructFieldType,
                            else => unreachable,
                        };
                }

                inline for (params.decls) |param_decl| {
                    const decl_validator = field.init(param_decl);
                    _ = decl_validator.eval(actual) catch |err|
                        return switch (err) {
                            decl.Error.AssertsDecl => StructError.AssertsDeclName,
                            else => unreachable,
                        };
                }

                _ = is_tuple_validator.eval(actual_info.is_tuple) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue => StructError.AssertsTrueIsTuple,
                        toggle.Error.AssertsFalse => StructError.AssertsFalseIsTuple,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    StructError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

                    StructError.BanishesLayout,
                    StructError.RequiresLayout,
                    => layout_validator.onError(err, prototype, @typeInfo(actual).@"struct".layout),

                    StructError.AssertsStructFieldName,
                    StructError.BanishesStructFieldType,
                    StructError.RequiresStructFieldType,
                    => {
                        inline for (params.fields) |param_field| {
                            const field_validator = field.init(param_field);
                            _ = field_validator.eval(actual) catch field_validator.onError(err, prototype, actual);
                        }
                    },

                    StructError.AssertsDeclName,
                    => {
                        inline for (params.decls) |param_decl| {
                            const decl_validator = field.init(param_decl);
                            _ = decl_validator.eval(actual) catch decl_validator.onError(err, prototype, actual);
                        }
                    },

                    StructError.AssertsTrueIsTuple,
                    StructError.AssertsFalseIsTuple,
                    => is_tuple_validator.onError(err, prototype, @typeInfo(actual).@"struct".is_tuple),

                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => info_validator.onError(err, prototype, actual),

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

    _ = StructError.AssertsStructFieldName catch void;
    _ = StructError.RequiresStructFieldType catch void;

    _ = StructError.AssertsDeclName catch void;

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
