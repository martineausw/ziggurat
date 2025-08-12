//! Auxillary prototype for declaration within given type.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for declaration.
const DeclError = error{
    InvalidArgument,
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
    .@"opaque" = true,
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
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => DeclError.InvalidArgument,
                        else => unreachable,
                    };

                if (!@hasDecl(actual, params.name)) {
                    return DeclError.AssertsDecl;
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    DeclError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

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

test DeclError {}

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
