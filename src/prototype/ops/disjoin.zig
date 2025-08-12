//! `disjoin` definition.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

pub const info_validator = info.init(.{
    .array = true,
    .pointer = true,
    .vector = true,
});

/// Boolean OR of `prototype`.
pub fn disjoin(prototypes: Prototype) Prototype {
    comptime var results: [prototypes.len]bool = undefined;
    comptime var errs: [prototypes.len]?anyerror = undefined;

    inline for (0..prototypes.len) |i| {
        results[i] = false;
        errs[i] = null;
    }

    return .{
        .name = "disjoin",
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
                    result = result or results[i];

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

test disjoin {
    const @"true": Prototype = .{
        .name = "true",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return true;
            }
        }.eval,
    };
    const @"false": Prototype = .{
        .name = "false",
        .eval = struct {
            fn eval(_: anytype) !bool {
                return false;
            }
        }.eval,
    };

    _ = try disjoin(.{ @"true", @"false" }).eval(void);
}
