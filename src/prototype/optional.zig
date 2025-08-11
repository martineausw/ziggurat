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
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
};

/// Error set returned by `eval`
pub const Error = OptionalError || info.Error;

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.DisallowedChild catch void;
    _ = Error.UnexpectedChild catch void;
}

pub const info_validator = info.init(.{
    .optional = true,
});

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Optional`.
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},
};

test {
    const params: Params = .{
        .child = .{},
    };

    _ = params;
}

/// Expects optional type value.
///
/// `actual` is an optional type value.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);

    return .{
        .name = "Optional",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try info_validator.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .optional => |optional_info| optional_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.DisallowedType => Error.DisallowedChild,
                        info.Error.UnexpectedType => Error.UnexpectedChild,
                        else => unreachable,
                    };
                };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    Error.DisallowedSize,
                    Error.UnexpectedSize,
                    => info_validator.onError(err, prototype, actual),

                    Error.DisallowedChild,
                    Error.UnexpectedChild,
                    => child_validator.onError(err, prototype, actual),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test init {
    const optional = init(.{
        .child = .{},
    });

    try testing.expectEqual(
        true,
        optional.eval(?bool),
    );

    try testing.expectEqual(
        Error.UnexpectedType,
        optional.eval(bool),
    );
}
