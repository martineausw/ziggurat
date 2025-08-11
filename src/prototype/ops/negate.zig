///! `negate` definition.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../../Prototype.zig");

/// Boolean NOT of given `prototype`
pub fn negate(prototype: Prototype) Prototype {
    return .{
        .name = std.fmt.comptimePrint("(NOT {s})", .{prototype.name}),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (prototype.eval(actual)) |result| {
                    return !result;
                } else |err| {
                    return err;
                }
            }
        }.eval,
        .onError = prototype.onError,
    };
}

test negate {
    const @"true": Prototype = .{
        .name = "True",
        .eval = struct {
            fn eval(_: anytype) anyerror!bool {
                return true;
            }
        }.eval,
    };

    try testing.expect(false == try negate(@"true").eval(void));
}
