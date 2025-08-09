//! Term to filter for runtime integer type values with parameterized
//! bits and signedness.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

const IntError = error{
    /// Violated signedness preference.
    InvalidSignedness,
};

const Error = IntError || interval.Error || info.Error;

pub const Params = struct {
    /// Valid bits interval for integer type
    bits: interval.Params(u16) = .{},
    /// Valid signedness
    signedness: ?std.builtin.Signedness = null,
};

/// Expects runtime int type value.
///
/// `actual` is runtime integer type value, otherwise returns error.
///
/// `actual` type info `bits` is within given `params`, otherwise returns error.
///
/// `actual` type info `signedness` is equal to given `params`, otherwise
/// returns error.
pub fn Has(params: Params) Term {
    const Is = info.Has(.{
        .int = true,
    });

    const Bits = interval.In(u16, params.bits);

    return .{
        .name = "IsIntType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = Is.eval(actual) catch |err| return err;

                const actual_info = switch (@typeInfo(actual)) {
                    .int => |int_info| int_info,
                    else => unreachable,
                };

                _ = Bits.eval(actual_info.bits) catch |err| return err;

                if (params.signedness) |signedness| {
                    if (signedness != actual_info.signedness)
                        return Error.InvalidSignedness;
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    .InvalidType,
                    .DisallowedInfo,
                    .DisallowedSize,
                    => Is.onError(err, term, actual),

                    .ExceedsMin,
                    .ExceedsMax,
                    => Bits.onError(err, term, actual),

                    .InvalidSignedness,
                    => std.fmt.comptimePrint(
                        "{s}.{s} expects {s}, actual: {s}",
                        .{
                            term.name,
                            @errorName(err),
                            @tagName(params.signedness),
                            @typeName(actual),
                        },
                    ),
                }
            }
        }.onError,
    };
}

test Has {
    const SignedInt = Has(
        .{ .signedness = .signed },
    );

    try testing.expectEqual(true, SignedInt.eval(i16));
    try testing.expectEqual(true, SignedInt.eval(i128));
    try testing.expectEqual(
        error.InvalidSignedness,
        SignedInt.eval(usize),
    );
    try testing.expectEqual(error.UnexpectedInfo, SignedInt.eval(f16));
}

test {
    std.testing.refAllDecls(@This());
}
