//! Term to filter for for pointer type values with parameterized size,
//! const and volatile qualifiers, and whether a sentinel value exists.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Error set for array
const ArrayError = error{
    /// Violates `sentinel` assertion
    InvalidSentinel,
};

/// Error set returned by `eval`
pub const Error = ArrayError || interval.Error || info.Error;

/// Parameters for term evaluation.
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
pub fn Has(params: Params) Term {
    const Info = info.Has(.{
        .array = true,
    });

    const Len = interval.In(comptime_int, params.len);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try Info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .array => |array_info| array_info,
                    else => unreachable,
                };

                _ = try Len.eval(actual_info.len);

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
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    .InvalidType,
                    .ActiveExclusion,
                    .InactiveInclusions,
                    => Info.onError(err, term, actual),

                    .InvalidSentinel,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?)
                            "sentinel value"
                        else
                            "sentinel value omitted",
                    }),
                }
            }
        }.onError,
    };
}

test Has {
    const Array = Has(.{
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    });

    try testing.expectEqual(
        true,
        Array.eval([5]u8),
    );

    try testing.expectEqual(
        Error.UnexpectedInfo,
        Array.eval([]const u8),
    );
}

test {
    std.testing.refAllDecls(@This());
}
