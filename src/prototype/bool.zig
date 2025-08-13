//! Prototype for `type` value with bool type info.
//!
//! `eval` asserts `bool` type value.
const std = @import("std");

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");

const BoolError = error{
    InvalidArgument,
};

/// Error set returned by `eval`.
pub const Error = BoolError;

/// Validates type info of `actual` to continue.
pub const info_validator = info.init(.{
    .bool = true,
});

pub const init: Prototype = .{
    .name = "Bool",
    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            _ = comptime info_validator.eval(
                actual,
            ) catch |err|
                return switch (err) {
                    info.Error.InvalidArgument,
                    info.Error.RequiresType,
                    => BoolError.InvalidArgument,
                    else => unreachable,
                };

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
                BoolError.InvalidArgument,
                => info_validator.onError(err, prototype, actual),

                else => unreachable,
            }
        }
    }.onError,
};

test BoolError {
    _ = BoolError.InvalidArgument catch void;
}

test init {
    const @"bool": Prototype = init;

    _ = @"bool";
}

test "evaluates bool successfully" {
    const @"bool" = init;

    try std.testing.expectEqual(true, @"bool".eval(bool));
}

test "coerces BoolError.InvalidArgument" {
    const @"bool" = init;

    try std.testing.expectEqual(BoolError.InvalidArgument, comptime @"bool".eval(true));
}
