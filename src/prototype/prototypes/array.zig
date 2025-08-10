//! Prototype to filter for for array type values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Error set for array
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

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Array`.
pub const Params = struct {
    /// Evaluates against `.len`
    len: interval.Params(comptime_int) = .{},

    /// Evaluates against `.child`
    child: info.Params = .{},

    /// Evaluates against `.sentinel()`.
    ///
    /// - `null`, no assertion.
    /// - `true`, asserts not `null`.
    /// - `false`, asserts `null`.
    sentinel: ?bool = null,
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
    const validator_info = info.init(.{
        .array = true,
    });

    const validator_child = info.init(params.child);

    const validator_len = interval.init(comptime_int, params.len);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try validator_info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .array => |array_info| array_info,
                    else => unreachable,
                };

                _ = validator_child.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.DisallowedType => Error.DisallowedChild,
                        info.Error.UnexpectedType => Error.UnexpectedChild,
                        else => unreachable,
                    };
                };

                _ = try validator_len.eval(actual_info.len);

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
                    => validator_info.onError(err, prototype, actual),

                    Error.UnexpectedChild,
                    Error.DisallowedChild,
                    => validator_child.onError(err, prototype, actual),

                    Error.ExceedsMin,
                    Error.ExceedsMax,
                    => validator_len.onError(err, prototype, actual),

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

test {
    std.testing.refAllDecls(@This());
}
