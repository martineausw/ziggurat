//! Term to filter for optional type values.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
const info = @import("../aux/info.zig");

/// Error set returned by `eval`
pub const Error = info.Error;

/// Parameters for term evaluation.
///
/// Associated with `std.builtin.Type.Optional`.
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},
};

/// Expects optional type value.
///
/// `actual` is an optional type value.
pub fn Has(params: Params) Term {
    const Info = info.Has(.{
        .optional = true,
    });

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try Info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .optional => |optional_info| optional_info,
                    else => unreachable,
                };

                _ = try info.Has(params.child).eval(actual_info.child);

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    .InvalidType,
                    .ActiveExclusion,
                    .InactiveInclusions,
                    => Info.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test Has {
    const Optional = Has(.{});

    try testing.expectEqual(
        true,
        Optional.eval(?bool),
    );

    try testing.expectEqual(
        Error.UnexpectedInfo,
        Optional.eval(bool),
    );
}

test {
    std.testing.refAllDecls(@This());
}
