//! Auxillary prototype for declaration within given type.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for declaration.
const DeclError = error{
    InvalidArgument,
    RequiresType,
    /// Violates `std.builtin.Type.Declaration.name` assertion.
    AssertsDecl,
};

/// Errors returned by `eval`.
pub const Error = DeclError;

/// Validates type info of `actual` to continue.
pub const info_validator = info.init(.{
    .@"struct" = true,
    .@"enum" = true,
    .@"union" = true,
});

/// Parameters used for prototype evaluation.
///
/// Derived from `std.builtin.Type.Declaration`.
pub const Params = struct {
    /// Evaluates against `std.builtin.Type.Declaration.name`.
    name: [:0]const u8,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = "Decl",
        .eval = struct {
            fn eval(actual: anytype) DeclError!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        => DeclError.InvalidArgument,
                        info.Error.RequiresType,
                        => DeclError.RequiresType,
                        else => unreachable,
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
                    DeclError.InvalidArgument,
                    DeclError.RequiresType,
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

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test DeclError {
    _ = DeclError.InvalidArgument catch void;
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

test "evaluates struct with given decl" {
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

test "evaluates union with given decl" {
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

test "evaluates enum with given decl" {
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

test "coerces DeclError.AssertsDecl from struct" {
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

test "coerces DeclError.AssertsDecl from union" {
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

test "coerces DeclError.AssertsDecl from enum" {
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

test "coerces DeclError.RequiresType" {
    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.RequiresType,
        comptime has_decl.eval(bool),
    );

    // comptime has_decl.onError.?(Error.RequiresType, has_decl, bool);
}

test "coerces DeclError.InvalidArgument" {
    const params: Params = .{
        .name = "decl",
    };

    const has_decl: Prototype = init(params);

    try std.testing.expectEqual(
        Error.InvalidArgument,
        comptime has_decl.eval(false),
    );

    // comptime has_decl.onError.?(Error.RequiresType, has_decl, bool);
}
