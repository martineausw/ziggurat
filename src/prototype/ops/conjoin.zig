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
    return .{
        .name = "Conjoin",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                var results: [prototypes.len]bool = undefined;
                var errs: [prototypes.len]?anyerror = undefined;

                for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                inline for (prototypes, 0..) |prototype, i| {
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
            fn onError(
                _: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                var results = [prototypes.len]bool{};
                var errs = [prototypes.len]?anyerror{};

                for (0..prototypes.len) |i| {
                    results[i] = false;
                    errs[i] = null;
                }

                for (prototypes, 0..) |proto, i| {
                    if (proto.eval(actual)) |result| {
                        results[i] = result;
                    } else |err| {
                        errs[i] = err;
                    }
                }

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
    _ = conjoin(.{
        Prototype{
            .name = "prototype",
            .eval = struct {
                fn eval(actual: anytype) !bool {
                    _ = actual;
                    return true;
                }
            }.eval,
        },
    });
}
