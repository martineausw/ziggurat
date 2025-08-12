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
                        info.Error.InvalidType,
                        info.Error.ViolatedWhitelistType,
                        => IntervalError.InvalidArgument,
                    };

                if (!((params.min orelse actual) <= actual))
                    return IntervalError.ExceedsMin;
                if (!((params.max orelse actual) >= actual))
                    return IntervalError.ExceedsMax;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    IntervalError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

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
    _ = IntervalError.ExceedsMin catch void;
    _ = IntervalError.ExceedsMax catch void;
}

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.ExceedsMin catch void;
    _ = Error.ExceedsMax catch void;
}

test info_validator {
    _ = try info_validator.eval(u8);
    _ = try info_validator.eval(f128);
    _ = try info_validator.eval(comptime_int);
    _ = try info_validator.eval(comptime_float);
}

test Params {
    const params: Params(comptime_int) = .{
        .min = null,
        .max = null,
    };

    _ = params;
}

test init {
    const usize_interval: Prototype = init(usize, .{
        .min = @as(usize, 1),
        .max = @as(usize, 2),
    });

    try testing.expectEqual(Error.ExceedsMin, usize_interval.eval(0));
    try testing.expectEqual(true, usize_interval.eval(1));
    try testing.expectEqual(true, usize_interval.eval(2));
    try testing.expectEqual(Error.ExceedsMax, usize_interval.eval(3));
}
