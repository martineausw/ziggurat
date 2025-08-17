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
    ExpectsTypeValue,
    RequiresTypeInfo,
    /// Violates `std.builtin.Type.Optional.child` blacklist assertion.
    BanishesChildTypeInfo,
    /// Violates `std.builtin.Type.Optional.child` whitelist assertion.
    RequiresChildTypeInfo,
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
                        info.Error.ExpectsTypeValue,
                        => OptionalError.ExpectsTypeValue,
                        info.Error.RequiresTypeInfo,
                        => OptionalError.RequiresTypeInfo,
                        else => unreachable,
                    };

                const actual_info = switch (@typeInfo(actual)) {
                    .optional => |optional_info| optional_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err|
                    return switch (err) {
                        info.Error.BanishesTypeInfo,
                        => OptionalError.BanishesChildTypeInfo,
                        info.Error.RequiresTypeInfo,
                        => OptionalError.RequiresChildTypeInfo,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    OptionalError.ExpectsTypeValue,
                    OptionalError.RequiresTypeInfo,
                    => info_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    OptionalError.BanishesChildTypeInfo,
                    OptionalError.RequiresChildTypeInfo,
                    => child_validator.onError.?(
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
    _ = OptionalError.ExpectsTypeValue catch void;
    _ = OptionalError.RequiresTypeInfo catch void;
    _ = OptionalError.BanishesChildTypeInfo catch void;
    _ = OptionalError.RequiresChildTypeInfo catch void;
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

test "passes optional assertions" {
    const optional = init(.{
        .child = .{},
    });

    try std.testing.expectEqual(true, optional.eval(?bool));
}

test "fails optional child type info blacklist assertions" {
    const optional = init(.{
        .child = .{
            .bool = false,
        },
    });

    try std.testing.expectEqual(OptionalError.BanishesChildTypeInfo, optional.eval(?bool));
}

test "fails optional child type info whitelist assertions" {
    const optional = init(.{
        .child = .{
            .int = true,
        },
    });

    try std.testing.expectEqual(OptionalError.RequiresChildTypeInfo, optional.eval(?bool));
}
