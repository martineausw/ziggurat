//! Auxillary prototype to specify an inclusive interval for number values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for interval.
const IntervalError = error{
    /// Violates inclusive minimum value assertion.
    ExceedsMin,
    /// Violates inclusive maximum value assertion.
    ExceedsMax,
};

/// Error set returned by `eval`
pub const Error = IntervalError || info.Error;

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.ExceedsMin catch void;
    _ = Error.ExceedsMax catch void;
}

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

        pub fn eval(self: Params(T), actual: T) Error!bool {
            if (!((self.min orelse actual) <= actual))
                return Error.ExceedsMin;
            if (!((self.max orelse actual) >= actual))
                return Error.ExceedsMax;
            return true;
        }

        pub fn onError(
            self: Params(T),
            err: Error,
            prototype: Prototype,
            actual: anytype,
        ) void {
            const print_val = switch (err) {
                Error.ExceedsMin => self.min.?,
                Error.ExceedsMax => self.max.?,
                else => unreachable,
            };
            @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {d} actual: @as({s}, {d})",
                .{
                    prototype.name,
                    @errorName(err),
                    print_val,
                    @typeName(T),
                    actual,
                },
            ));
        }
    };
}

test Params {
    const params: Params(comptime_int) = .{
        .min = null,
        .max = null,
    };

    _ = params;
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
    const validator_info = info.init(.{
        .int = true,
        .comptime_int = true,
        .float = true,
        .comptime_float = true,
    });

    const validator_interval = params;

    return .{
        .name = "Interval",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = validator_info.eval(T) catch |err| return err;
                _ = validator_interval.eval(actual) catch |err| return err;
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => validator_info.onError(err, prototype, actual),

                    Error.ExceedsMin,
                    Error.ExceedsMax,
                    => validator_interval.onError(err, prototype, actual),
                }
            }
        }.onError,
    };
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
