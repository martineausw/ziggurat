//! Prototype for `type` value with optional type info.
//!
//! `eval` asserts optional type within parameters:
//!
//! - `child`, type info filter assertion.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");

/// Error set for optional.
const OptionalError = error{
    InvalidArgument,
    /// Violates `std.builtin.Type.Optional.child` blacklist assertion.
    BanishesChildType,
    /// Violates `std.builtin.Type.Optional.child` whitelist assertion.
    RequiresChildType,
};

/// Error set returned by `eval`
pub const Error = OptionalError;

/// Validates `actual` type info to optional to continue.
pub const info_validator = info.init(.{
    .optional = true,
});

/// Parameters for prototype evaluation.
///
/// Derived from `std.builtin.Type.Optional`.
pub const Params = struct {
    /// Evaluates against `std.builtin.Type.optional.child`
    child: info.Params = .{},
};

/// Expects optional type value.
///
/// `actual` assertions:
///
/// `actual` is an optional type value.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);

    return .{
        .name = "Optional",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => OptionalError.InvalidArgument,
                        else => unreachable,
                    };

                const actual_info = switch (@typeInfo(actual)) {
                    .optional => |optional_info| optional_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err|
                    return switch (err) {
                        info.Error.BanishesType,
                        => OptionalError.BanishesChildType,
                        info.Error.RequiresType,
                        => OptionalError.RequiresChildType,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    OptionalError.InvalidArgument => info_validator.onError(
                        err,
                        prototype,
                        actual,
                    ),

                    OptionalError.BanishesChildType,
                    OptionalError.RequiresChildType,
                    => child_validator.onError(
                        err,
                        prototype,
                        @typeInfo(actual).optional.child,
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test OptionalError {
    _ = OptionalError.InvalidArgument catch void;
    _ = OptionalError.BanishesChildType catch void;
    _ = OptionalError.RequiresChildType catch void;
}

test Params {
    const params: Params = .{
        .child = .{},
    };

    _ = params;
}

test init {
    const optional = init(.{
        .child = .{
            .bool = true,
        },
    });

    _ = optional;
}

test "evaluates optional successfully" {
    const optional = init(.{
        .child = .{},
    });

    try std.testing.expectEqual(true, optional.eval(?bool));
}

test "coerces OptionalError.BanishesChildType" {
    const optional = init(.{
        .child = .{
            .bool = false,
        },
    });

    try std.testing.expectEqual(OptionalError.BanishesChildType, optional.eval(?bool));
}

test "coerces OptionalError.RequiresChildType" {
    const optional = init(.{
        .child = .{
            .int = true,
        },
    });

    try std.testing.expectEqual(OptionalError.RequiresChildType, optional.eval(?bool));
}
