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
const filter = @import("aux/filter.zig");

/// Error set for int
const IntError = error{
    InvalidArgument,
    RequiresTypeInfo,
    AssertsMinBits,
    AssertsMaxBits,
    /// Violates `std.builtin.Type.Int.signedness` assertion.
    BanishesSignedness,
    RequiresSignedness,
};

/// Error set returned by `eval`
pub const Error = IntError;

/// Validates type info of `actual` to continue.
pub const info_validator = info.init(.{
    .int = true,
});

const SignednessParams = struct {
    signed: ?bool = null,
    unsigned: ?bool = null,
};

const Signedness = filter.Filter(SignednessParams);

/// Parameters for prototype evaluation
///
/// Associated with `std.builtin.Type.Int`
pub const Params = struct {
    /// Evaluates against `.bits`
    bits: interval.Params = .{},
    /// Evaluates against `.signedness`
    ///
    /// - `null`, no assertion
    /// - `signed`, asserts `signed`
    /// - `unsigned`, asserts `unsigned`
    signedness: SignednessParams = .{},
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
    const bits_validator = interval.init(params.bits);
    const signedness_validator = Signedness.init(params.signedness);

    return .{
        .name = "Int",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        => IntError.InvalidArgument,
                        info.Error.RequiresTypeInfo,
                        => IntError.RequiresTypeInfo,
                        else => unreachable,
                    };

                const actual_info = switch (@typeInfo(actual)) {
                    .int => |int_info| int_info,
                    else => unreachable,
                };

                _ = bits_validator.eval(actual_info.bits) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin => IntError.AssertsMinBits,
                        interval.Error.AssertsMax => IntError.AssertsMaxBits,
                        else => unreachable,
                    };

                _ = comptime signedness_validator.eval(
                    actual_info.signedness,
                ) catch |err|
                    return switch (err) {
                        filter.Error.Banishes => IntError.BanishesSignedness,
                        filter.Error.Requires => IntError.RequiresSignedness,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    IntError.InvalidArgument,
                    IntError.RequiresTypeInfo,
                    => info_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    IntError.AssertsMinBits,
                    IntError.AssertsMaxBits,
                    => bits_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).int.bits,
                    ),

                    IntError.BanishesSignedness,
                    IntError.RequiresSignedness,
                    => signedness_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).int.signedness,
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test IntError {
    _ = IntError.InvalidArgument catch void;
    _ = IntError.AssertsMinBits catch void;
    _ = IntError.AssertsMaxBits catch void;
    _ = IntError.BanishesSignedness catch void;
    _ = IntError.RequiresSignedness catch void;
}

test Params {
    const params: Params = .{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .signed = null,
            .unsigned = null,
        },
    };

    _ = params;
}

test init {
    const int: Prototype = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .signed = null,
            .unsigned = null,
        },
    });

    _ = int;
}

test "evaluates int successfully" {
    const int = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{},
    });

    try std.testing.expectEqual(true, int.eval(i128));
    try std.testing.expectEqual(true, int.eval(usize));
}

test "coerces IntError.InvalidArgument" {
    const int = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{},
    });

    try std.testing.expectEqual(
        IntError.InvalidArgument,
        comptime int.eval(@as(i128, 0)),
    );
}

test "coerces IntError.AssertsMinBits and IntError.AssertsMaxBits" {
    const int = init(.{
        .bits = .{
            .min = 32,
            .max = 64,
        },
        .signedness = .{},
    });

    try std.testing.expectEqual(IntError.AssertsMinBits, comptime int.eval(i16));
    try std.testing.expectEqual(IntError.AssertsMaxBits, comptime int.eval(i128));
}

test "coerces IntError.BanishesSignedness" {
    const int = init(.{ .bits = .{
        .min = null,
        .max = null,
    }, .signedness = .{
        .signed = false,
    } });

    try std.testing.expectEqual(IntError.BanishesSignedness, comptime int.eval(i128));
}

test "coerces IntError.RequiresSignedness" {
    const int = init(.{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .unsigned = true,
        },
    });

    try std.testing.expectEqual(IntError.RequiresSignedness, comptime int.eval(i128));
}
