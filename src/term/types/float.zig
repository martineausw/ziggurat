//! Term to filter for runtime float type values with parameterized bits.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");

const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Errors returned by `eval`
pub const Error = info.Error || interval.Error;

/// Associated with `std.builtin.Type.Float`
pub const Params = struct {
    /// Evaluates against `.bits`
    bits: interval.Params(u16) = .{},
};

/// Expects runtime float type value.
///
/// `actual` is runtime float type value, otherwise returns error.
///
/// `actual` type info `bits` is within given `params`, otherwise returns
/// error.
pub fn Has(params: Params) Term {
    const Info = info.Has(.{
        .float = true,
    });

    const Bits = interval.In(u16, params.bits);

    return .{
        .name = "FloatType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try Info.eval(actual);
                const actual_info = switch (@typeInfo(actual)) {
                    .float => |float_info| float_info,
                    else => unreachable,
                };
                _ = try Bits.eval(actual_info.bits);
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    .InvalidType,
                    .DisallowedInfo,
                    .UnexpectedInfo,
                    => Info.onError(err, term, actual),

                    .ExceedsMin,
                    .ExceedsMax,
                    => Bits.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test Has {
    const Float32 = Has(.{
        .bits = .{
            .min = 32,
            .max = 32,
        },
    });

    try testing.expectEqual(error.ExceedsMin, Float32.eval(f16));
    try testing.expectEqual(true, Float32.eval(f32));
    try testing.expectEqual(error.ExceedsMax, Float32.eval(f128));
}

test {
    std.testing.refAllDecls(@This());
}
