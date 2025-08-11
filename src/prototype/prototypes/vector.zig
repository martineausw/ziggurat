//! Prototype to filter for vector type values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Error set for vector.
const VectorError = error{
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
};

/// Error set returned by `eval`.
pub const Error = VectorError || interval.Error || info.Error;

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Vector`.
pub const Params = struct {
    /// Evaluates against `.len`.
    len: interval.Params(comptime_int) = .{},

    /// Evaluates against `.child`
    child: info.Params = .{},
};

/// Expects vector type value.
///
/// `actual` is a vector type value.
///
/// `actual` type info `len` is within given `params`.
pub fn init(params: Params) Prototype {
    const validator_info = info.init(.{
        .vector = true,
    });

    const validator_child = info.init(params.child);

    const validator_len = interval.init(comptime_int, params.len);

    return .{
        .name = "Vector",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try validator_info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .vector => |vector_info| vector_info,
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

                _ = try validator_child.eval(actual_info.child);

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    Error.DisallowedInfo,
                    Error.UnexpectedType,
                    => validator_info.onError(err, prototype, actual),

                    Error.DisallowedChild,
                    Error.UnexpectedChild,
                    => validator_child.onError(err, prototype, actual),

                    Error.ExceedsMin,
                    Error.ExceedsMax,
                    => validator_len.onError(err, prototype, actual),

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

test {
    std.testing.refAllDecls(@This());
}
