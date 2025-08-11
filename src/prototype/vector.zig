//! Prototype for `type` value with vector type info.
//!
//! `eval` asserts vector type within parameters:
//!
//! - `child`, type info filter assertion.
//! - `len`, type info interval assertion.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

/// Error set for vector.
const VectorError = error{
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
};

/// Error set returned by `eval`.
pub const Error = VectorError || interval.Error || info.Error;

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.DisallowedChild catch void;
    _ = Error.UnexpectedChild catch void;

    _ = Error.ExceedsMin catch void;
    _ = Error.ExceedsMax catch void;
}

pub const info_validator = info.init(.{
    .vector = true,
});

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Vector`.
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},

    /// Evaluates against `.len`.
    len: interval.Params(comptime_int) = .{},
};

test Params {
    const params: Params = .{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    };
    _ = params;
}

/// Expects vector type value.
///
/// `actual` is a vector type value.
///
/// `actual` type info `len` is within given `params`.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const len_validator = interval.init(comptime_int, params.len);

    return .{
        .name = "Vector",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try info_validator.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .vector => |vector_info| vector_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.DisallowedType => Error.DisallowedChild,
                        info.Error.UnexpectedType => Error.UnexpectedChild,
                        else => unreachable,
                    };
                };

                _ = try len_validator.eval(actual_info.len);

                _ = try child_validator.eval(actual_info.child);

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => info_validator.onError(err, prototype, actual),

                    Error.DisallowedChild,
                    Error.UnexpectedChild,
                    => child_validator.onError(err, prototype, actual),

                    Error.ExceedsMin,
                    Error.ExceedsMax,
                    => len_validator.onError(err, prototype, actual),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test init {
    const vector = init(.{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try testing.expectEqual(
        true,
        vector.eval(@Vector(5, u8)),
    );

    try testing.expectEqual(
        Error.UnexpectedType,
        vector.eval([5]u8),
    );
}
