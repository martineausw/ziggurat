//! Prototype for optional type values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../../Prototype.zig");
const info = @import("../aux/info.zig");

/// Error set for optional.
const OptionalError = error{
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
};

/// Error set returned by `eval`
pub const Error = OptionalError || info.Error;

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Optional`.
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},
};

/// Expects optional type value.
///
/// `actual` is an optional type value.
pub fn init(params: Params) Prototype {
    const validator_info = info.init(.{
        .optional = true,
    });

    const validator_child = info.init(params.child);

    return .{
        .name = "Optional",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try validator_info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .optional => |optional_info| optional_info,
                    else => unreachable,
                };

                _ = validator_child.eval(actual_info.child) catch |err| {
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
                    => validator_info.onError(err, prototype, actual),

                    Error.DisallowedChild,
                    Error.UnexpectedChild,
                    => validator_child.onError(err, prototype, actual),

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

test {
    std.testing.refAllDecls(@This());
}
