//! Evaluates a *type* value with type info containing *declarations*.
//!
//! See also:
//! - [`std.builtin.Type.Enum`](#std.builtin.Type.Enum)
//! - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
//! - [`std.builtin.Type.Union`](#std.builtin.Type.Union)
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for *decl* prototype.
const DeclError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires struct, enum, or union type info.
    AssertsWhitelistTypeInfo,
    /// *actual* is missing declaration.
    AssertsDecl,
};

pub const Error = DeclError;

/// Type info assertions for *decl* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const info_validator = info.init(.{
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
        .name = "Decl",
        .eval = struct {
            fn eval(actual: anytype) DeclError!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => DeclError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => DeclError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (!@hasDecl(actual, params.name)) {
                    return DeclError.AssertsDecl;
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
                    DeclError.AssertsTypeValue,
                    DeclError.AssertsWhitelistTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    DeclError.AssertsDecl,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params.name,
                        },
                    )),

                    else => @panic("unhandled error"),
                }
            }
        }.onError,
    };
}

test DeclError {
    _ = DeclError.AssertsTypeValue catch void;
    _ = DeclError.AssertsDecl catch void;
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

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_decl.eval(T),
    );
}

test "passes declaration assertion on union" {
    const T: type = union {
        const decl = void;
    };

    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_decl.eval(T),
    );
}

test "passes declaration assertion on enum" {
    const T: type = enum {
        const decl = void;
    };

    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_decl.eval(T),
    );
}

test "fails declaration assertions on struct" {
    const T: type = struct {};

    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsDecl,
        has_decl.eval(T),
    );

    // has_decl.onError.?(Error.AssertsDecl, has_decl, T);
}

test "fails declaration assertion on union" {
    const T: type = union {};

    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsDecl,
        has_decl.eval(T),
    );

    // comptime has_decl.onError.?(Error.AssertsDecl, has_decl, T);
}

test "fails declaration assertion on enum" {
    const T: type = enum {};

    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsDecl,
        has_decl.eval(T),
    );

    // comptime has_decl.onError.?(Error.AssertsDecl, has_decl, T);
}

test "fails argument type info assertion" {
    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsWhitelistTypeInfo,
        comptime has_decl.eval(bool),
    );

    // comptime has_decl.onError.?(Error.AssertsWhitelistTypeInfo, has_decl, bool);
}

test "fails argument value assertion" {
    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.AssertsTypeValue,
        comptime has_decl.eval(false),
    );

    // comptime has_decl.onError.?(Error.AssertsWhitelistTypeInfo, has_decl, bool);
}
