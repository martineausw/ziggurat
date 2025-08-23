const Prototype = @import("prototype/Prototype.zig");

pub fn sign(prototype: Prototype) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (comptime prototype.eval(actual)) |result| {
                if (!result) if (prototype.onFail) |onFail| {
                    comptime onFail(prototype, actual);
                };
            } else |err| {
                if (prototype.onError) |onError| {
                    comptime onError(err, prototype, actual);
                }
            }

            return struct {
                pub fn returns(comptime return_type: type) type {
                    return return_type;
                }
            }.returns;
        }
    }.validate;
}
