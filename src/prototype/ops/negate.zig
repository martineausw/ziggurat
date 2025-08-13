///! `negate` definition.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");

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
    _ = negate(Prototype{
        .name = "prototype",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = actual;
                return true;
            }
        }.eval,
    });
}
