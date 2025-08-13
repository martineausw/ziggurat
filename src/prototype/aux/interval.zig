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
