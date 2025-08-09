//! Auxillary term to specify an inclusive interval for number values.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
const info = @import("info.zig");

const IntervalError = error{
    /// Value is less than min.
    ExceedsMin,
    /// Value is greater than max.
    ExceedsMax,
};

pub const Error = IntervalError || info.Error;

pub fn Params(comptime T: type) type {
    return struct {
        /// Inclusive minimum
        min: ?T = null,
        /// Inclusive maximum
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
            term: Term,
            actual: anytype,
        ) void {
            const print_val = switch (err) {
                .ExceedsMin => self.min.?,
                .ExceedsMax => self.max.?,
            };
            @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {d} actual: @as({s}, {d})",
                .{
                    term.name,
                    @errorName(err),
                    print_val,
                    @typeName(T),
                    actual,
                },
            ));
        }
    };
}

/// Expects integer value.
///
/// Given type `T` is integer type, otherwise returns error.
///
/// `actual` is greater-than-or-equal-to given `params.min`, otherwise
/// error.
///
/// `actual` is less-than-or-equal-to given `params.max`, otherwise returns
/// error.
pub fn In(comptime T: type, params: Params(T)) Term {
    const ValidType = info.Has(.{
        .int = true,
        .comptime_int = true,
        .float = true,
        .comptime_float = true,
    });

    return .{
        .name = "Interval",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = ValidType.eval(T) catch |err| return err;
                _ = params.eval(actual) catch |err| return err;
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    .InvalidType,
                    .DisallowedInfo,
                    .UnexpectedInfo,
                    => ValidType.onError(err, term, actual),

                    .ExceedsMin,
                    .ExceedsMax,
                    => params.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test In {
    const IntRange: Term = In(usize, .{
        .min = @as(usize, 1),
        .max = @as(usize, 2),
    });

    try testing.expectEqual(error.ExceedsMin, IntRange.eval(0));
    try testing.expectEqual(true, IntRange.eval(1));
    try testing.expectEqual(true, IntRange.eval(2));
    try testing.expectEqual(error.ExceedsMax, IntRange.eval(3));
}

test {
    std.testing.refAllDecls(@This());
}
