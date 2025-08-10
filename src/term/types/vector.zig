//! Term to filter for for pointer type values with parameterized size,
//! const and volatile qualifiers, and whether a sentinel value exists.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Error set returned by `eval`
pub const Error = interval.Error || info.Error;

/// Parameters for term evaluation.
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
pub fn Has(params: Params) Term {
    const Info = info.Has(.{
        .vector = true,
    });

    const Len = interval.In(comptime_int, params.len);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try Info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .vector => |vector_info| vector_info,
                    else => unreachable,
                };

                _ = try Len.eval(actual_info.len);

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
    const Vector = Has(.{
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try testing.expectEqual(
        true,
        Vector.eval(@Vector(5, u8)),
    );

    try testing.expectEqual(
        Error.UnexpectedInfo,
        Vector.eval([5]u8),
    );
}

test {
    std.testing.refAllDecls(@This());
}
