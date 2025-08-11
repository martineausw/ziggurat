//! Prototype for `type` value runtime integer type info.
//!
//! `eval` asserts int type within parameters:
//!
//! - `bits`, type info interval assertion
//! - `signedness`, type info field assertion
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

/// Error set for int
const IntError = error{
    /// Violates `signedness` assertion.
    InvalidSignedness,
};

/// Error set returned by `eval`
pub const Error = IntError || interval.Error || info.Error;

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.ExceedsMin catch void;
    _ = Error.ExceedsMax catch void;

    _ = Error.InvalidSignedness catch void;
}

pub const info_validator = info.init(.{
    .int = true,
});

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

test Params {
    const params: Params = .{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = null,
    };

    _ = params;
}

/// Expects runtime int type value.
///
/// `actual` is runtime integer type value, otherwise returns error.
///
/// `actual` type info `bits` is within given `params`, otherwise returns error.
///
/// `actual` type info `signedness` is equal to given `params`, otherwise
/// returns error.
pub fn init(params: Params) Prototype {
    const bits_validator = interval.init(u16, params.bits);

    return .{
        .name = "Int",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err| return err;

                const actual_info = switch (@typeInfo(actual)) {
                    .int => |int_info| int_info,
                    else => unreachable,
                };

                _ = bits_validator.eval(actual_info.bits) catch |err| return err;

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
                    Error.UnexpectedType,
                    => info_validator.onError(err, prototype, actual),

                    Error.ExceedsMin,
                    Error.ExceedsMax,
                    => bits_validator.onError(err, prototype, actual),

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
