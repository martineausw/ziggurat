//! Auxillary prototype to specify an inclusive interval for number values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for interval.
const IntervalError = error{
    InvalidArgument,
    /// Violates inclusive minimum value assertion.
    AssertsMin,
    /// Violates inclusive maximum value assertion.
    AssertsMax,
};

/// Error set returned by `eval`
pub const Error = IntervalError;

pub const info_validator = info.init(.{
    .int = true,
    .float = true,
    .comptime_int = true,
    .comptime_float = true,
});

/// Parameters used for prototype evaluation.
pub fn Params(comptime T: type) type {
    return struct {
        /// Evaluates against `actual` value
        ///
        /// - `null`, no assertion.
        /// - not `null`, asserts less-than-or-equal-to.
        min: ?T = null,
        /// Evaluates against `actual` value
        ///
        /// - `null`, no assertion.
        /// - not `null`, asserts greater-than-or-equal-to.
        max: ?T = null,
    };
}

/// Expects integer value.
///
/// Given type `T` is integer type, otherwise returns error.
///
/// `actual` is greater-than-or-equal-to given `params.min`, otherwise
/// returns error.
///
/// `actual` is less-than-or-equal-to given `params.max`, otherwise returns
/// error.
pub fn init(comptime T: type, params: Params(T)) Prototype {
    return .{
        .name = "Interval",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(T) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        => IntervalError.InvalidArgument,
                        else => unreachable,
                    };

                if (!((params.min orelse actual) <= actual))
                    return IntervalError.AssertsMin;
                if (!((params.max orelse actual) >= actual))
                    return IntervalError.AssertsMax;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(
                err: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                switch (err) {
                    IntervalError.InvalidArgument,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {d}",
                        .{
                            prototype.name,
                            @errorName(err),
                            actual,
                        },
                    )),
                }
            }
        }.onError,
    };
}

test IntervalError {
    _ = IntervalError.InvalidArgument catch void;
    _ = IntervalError.AssertsMin catch void;
    _ = IntervalError.AssertsMax catch void;
}

test Params {
    const params: Params(comptime_int) = .{
        .min = null,
        .max = null,
    };

    _ = params;
}

test init {
    const interval: Prototype = init(comptime_int, .{
        .min = null,
        .max = null,
    });

    _ = interval;
}

test "evaluates runtime integers within interval" {
    const usize_interval = init(usize, .{
        .min = 0,
        .max = 2,
    });

    try std.testing.expectEqual(true, usize_interval.eval(@as(usize, 0)));
    try std.testing.expectEqual(true, usize_interval.eval(@as(usize, 1)));
    try std.testing.expectEqual(true, usize_interval.eval(@as(usize, 2)));

    const i128_interval = init(i128, .{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(true, i128_interval.eval(@as(i128, -1)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(i128, 0)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(i128, 1)));
}

test "evaluates runtime floats within interval" {
    const f16_interval = init(f16, .{
        .min = -1.0,
        .max = 1.0,
    });

    try std.testing.expectEqual(true, f16_interval.eval(@as(f16, -1.0)));
    try std.testing.expectEqual(true, f16_interval.eval(@as(f16, 0.0)));
    try std.testing.expectEqual(true, f16_interval.eval(@as(f16, 1.0)));

    const i128_interval = init(f128, .{
        .min = -1.0,
        .max = 1.0,
    });

    try std.testing.expectEqual(true, i128_interval.eval(@as(f128, -1)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(f128, 0)));
    try std.testing.expectEqual(true, i128_interval.eval(@as(f128, 1)));
}

test "evaluates comptime_int within interval" {
    const interval = init(comptime_int, .{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_int, -1)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_int, 0)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_int, 1)),
    );
}

test "evaluates comptime_float within interval" {
    const interval = init(comptime_float, .{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_float, -1)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_float, 0)),
    );

    try std.testing.expectEqual(
        true,
        interval.eval(@as(comptime_float, 1)),
    );
}

test "coerces IntervalError.AssertsMin" {
    const interval = init(comptime_float, .{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        IntervalError.AssertsMin,
        interval.eval(@as(comptime_float, -1.001)),
    );
}

test "coerces IntervalError.AssertsMax" {
    const interval = init(comptime_float, .{
        .min = -1,
        .max = 1,
    });

    try std.testing.expectEqual(
        IntervalError.AssertsMax,
        interval.eval(@as(comptime_float, 1.001)),
    );
}
