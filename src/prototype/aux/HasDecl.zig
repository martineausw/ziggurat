//! Auxiliary prototype that checks a type for a declaration.
//!
//! Asserts an *actual* struct, union, or enum type value to have a
//! declaration.
//!
//! See also:
//! - [`std.builtin.Type.Enum`](#std.builtin.Type.Enum)
//! - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
//! - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("FiltersTypeInfo.zig");

const Self = @This();

/// Error set for *HasDecl* prototype.
const HasDeclError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires struct, enum, or union type info.
    AssertsWhitelistTypeInfo,
    /// *actual* is missing declaration.
    AssertsHasDecl,
};

pub const Error = HasDeclError;

/// Type info assertions for *HasDecl* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .@"struct" = true,
    .@"enum" = true,
    .@"union" = true,
});

/// Assertion parameters for *decl* prototype.
///
/// See also:
/// - [`std.builtin.Type.Declaration`](#std.builtin.Type.Declaration).
/// - [`std.builtin.Type.Enum`](#std.builtin.Type.Enum)
/// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
/// - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
pub const Params = struct {
    /// Asserts declaration name.
    name: [:0]const u8,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) HasDeclError!bool {
                _ = comptime has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => HasDeclError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => HasDeclError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (!@hasDecl(actual, params.name)) {
                    return HasDeclError.AssertsHasDecl;
                }

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
                    HasDeclError.AssertsTypeValue,
                    HasDeclError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params.name,
                        },
                    )),
                }
            }
        }.onError,
    };
}

test HasDeclError {
    _ = HasDeclError.AssertsHasDecl catch void;
}

test Params {
    const T = struct {
        const decl = false;
    };

    _ = T;

    const params: Params = .{
        .name = "decl",
    };

    _ = params;
}

test init {
    const T = struct {
        const decl = false;
    };

    _ = T;

    const decl = init(.{
        .name = "decl",
    });

    _ = decl;
}

test "passes declaration assertion on struct" {
    const T: type = struct {
        const decl = void;
    };

    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        HasDecl.eval(T),
    );
}

test "passes declaration assertion on union" {
    const T: type = union {
        const decl = void;
    };

    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        HasDecl.eval(T),
    );
}

test "passes declaration assertion on enum" {
    const T: type = enum {
        const decl = void;
    };

    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        HasDecl.eval(T),
    );
}

test "fails declaration assertions on struct" {
    const T: type = struct {};

    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsHasDecl,
        HasDecl.eval(T),
    );

    // HasDecl.onError.?(Error.AssertsHasDecl, HasDecl, T);
}

test "fails declaration assertion on union" {
    const T: type = union {};

    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsHasDecl,
        HasDecl.eval(T),
    );

    // comptime HasDecl.onError.?(Error.AssertsHasDecl, HasDecl, T);
}

test "fails declaration assertion on enum" {
    const T: type = enum {};

    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsHasDecl,
        HasDecl.eval(T),
    );

    // comptime HasDecl.onError.?(Error.AssertsHasDecl, HasDecl, T);
}

test "fails argument type info assertion" {
    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime HasDecl.eval(bool),
    );

    // comptime HasDecl.onError.?(Error.AssertsWhitelistTypeInfo, HasDecl, bool);
}

test "fails argument value assertion" {
    const params: Params = .{
        .name = "decl",
    };

    const HasDecl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime HasDecl.eval(false),
    );

    // comptime HasDecl.onError.?(Error.AssertsWhitelistTypeInfo, HasDecl, bool);
}
