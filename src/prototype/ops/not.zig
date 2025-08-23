const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");

pub fn not(prototype: Prototype) Prototype {
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (comptime prototype.eval(actual)) |result| {
                    return !result;
                } else |err| {
                    return err;
                }
            }
        }.eval,
        .onError = prototype.onError,
    };
}
