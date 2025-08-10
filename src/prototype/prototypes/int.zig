//! Prototype to filter for runtime integer type values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Error set for int
const IntError = error{
    /// Violates `signedness` assertion.
    InvalidSignedness,
};

/// Error set returned by `eval`
const Error = IntError || interval.Error || info.Error;

/// Parameters for prototype evaluation
///
/// Associated with `std.builtin.Type.Int`
pub const Params = struct {
    /// Evaluates against `.bits`
    bits: interval.Params(u16) = .{},
    /// Evaluates against `.signedness`
    ///
    /// - `null`, no assertion
    /// - `signed`, asserts `signed`
    /// - `unsigned`, asserts `unsigned`
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
pub fn init(params: Params) Prototype {
    const validator_info = info.init(.{
        .int = true,
    });

    const validator_bits = interval.init(u16, params.bits);

    return .{
        .name = "Int",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = validator_info.eval(actual) catch |err| return err;

                const actual_info = switch (@typeInfo(actual)) {
                    .int => |int_info| int_info,
                    else => unreachable,
                };

                _ = validator_bits.eval(actual_info.bits) catch |err| return err;

                if (params.signedness) |signedness| {
                    if (signedness != actual_info.signedness)
                        return Error.InvalidSignedness;
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.DisallowedSize,
                    => validator_info.onError(err, prototype, actual),

                    Error.ExceedsMin,
                    Error.ExceedsMax,
                    => validator_bits.onError(err, prototype, actual),

                    Error.InvalidSignedness,
                    => std.fmt.comptimePrint(
                        "{s}.{s} expects {s}, actual: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            @tagName(params.signedness),
                            @typeName(actual),
                        },
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test init {
    const signed_int = init(
        .{ .signedness = .signed },
    );

    try testing.expectEqual(true, signed_int.eval(i16));
    try testing.expectEqual(true, signed_int.eval(i128));
    try testing.expectEqual(
        Error.InvalidSignedness,
        signed_int.eval(usize),
    );
    try testing.expectEqual(Error.UnexpectedType, signed_int.eval(f16));
}

test {
    std.testing.refAllDecls(@This());
}
