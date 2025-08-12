//! `conjoin` definition
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

const info_validator = info.init(.{
    .array = true,
    .vector = true,
    .pointer = true,
});

/// Boolean AND of given prototypes
pub fn conjoin(prototypes: anytype) Prototype {
    comptime var results: [prototypes.len]bool = undefined;
    comptime var errs: [prototypes.len]?anyerror = undefined;

    inline for (0..prototypes.len) |i| {
        results[i] = false;
        errs[i] = null;
    }

    return .{
        .name = "Conjoin",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                for (prototypes, 0..) |prototype, i| {
                    if (prototype.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                    }
                }

                var result = results[0];

                for (1..results.len) |i|
                    result = result and results[i];

                if (result) {
                    return true;
                }

                for (errs) |err| {
                    if (err) |e| {
                        return e;
                    }
                }

                return false;
            }
        }.eval,
        .onError = struct {
            fn onError(_: anyerror, prototype: Prototype, actual: anytype) void {
                for (0..prototypes.len) |i| {
                    if (errs[i]) |e| {
                        prototypes[i].onError(e, prototype, actual);
                    }
                }
            }
        }.onError,
    };
}

test conjoin {
    const @"true": Prototype = .{
        .name = "True",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };

    _ = try conjoin(.{ @"true", @"true" }).eval(void);
}
