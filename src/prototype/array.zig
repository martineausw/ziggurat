//! Prototype for `type` value with array type info.
//!
//! `eval` asserts array type within parameters:
//!
//! - `child`, type info filter assertion.
//! - `len`, type info interval assertion.
//! - `sentinel`, type info value assertion.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

/// Error set for array.
const ArrayError = error{
    /// Violates `sentinel` assertion.
    InvalidSentinel,
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
};

/// Error set returned by `eval`
pub const Error = ArrayError || interval.Error || info.Error;

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
    .array = true,
});

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Array`.
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},

    /// Evaluates against `.len`
    len: interval.Params(comptime_int) = .{},

    /// Evaluates against `.sentinel()`.
    ///
    /// - `null`, no assertion.
    /// - `true`, asserts not `null`.
    /// - `false`, asserts `null`.
    sentinel: ?bool = null,
};

test Params {
    const params: Params = .{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    };

    _ = params;
}

/// Expects array type value.
///
/// `actual` is an array type value.
///
/// `actual` type info `len` is within given `params`.
///
/// `actual` type info `sentinel()` is not-null when given params is true
/// or null when given params is false, otherwise returns error.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const len_validator = interval.init(comptime_int, params.len);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try info_validator.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .array => |array_info| array_info,
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

                if (params.sentinel) |sentinel| {
                    const actual_sentinel =
                        if (actual_info.sentinel()) |_| {
                            true;
                        } else {
                            false;
                        };

                    if (sentinel != actual_sentinel) |_|
                        return Error.InvalidSentinel;
                }

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

                    Error.InvalidSentinel,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        prototype.name,
                        @errorName(err),
                        if (params.is_const.?)
                            "sentinel value"
                        else
                            "sentinel value omitted",
                    }),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test init {
    const array = init(.{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    });

    try testing.expectEqual(
        true,
        array.eval([5]u8),
    );

    try testing.expectEqual(
        Error.UnexpectedType,
        array.eval([]const u8),
    );
}
