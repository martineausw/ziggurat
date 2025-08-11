///! `sign` definition.
const Prototype = @import("prototype/Prototype.zig");

/// Wraps the final prototype and invoked at return value position of a function signature.
///
/// Prototype must evaluate to true to continue.
///
/// Invokes `prototype.onFail` when `prototype.eval` returns `false`.
///
/// Invokes `prototype.onError` when `prototype.eval` returns error.
pub fn sign(prototype: Prototype) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (prototype.eval(actual)) |result| {
                if (!result) if (prototype.onFail) |onFail|
                    onFail(prototype, actual);
            } else |err| {
                if (prototype.onError) |onError|
                    onError(err, prototype, actual);
            }

            return struct {
                pub fn returns(comptime return_type: type) type {
                    return return_type;
                }
            }.returns;
        }
    }.validate;
}

test sign {
    const int: Prototype = .{
        .name = "Int",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    };

    const prototype_value: Prototype = int;
    const argument_value: u32 = 0;
    const return_type: type = void;

    _ = sign(prototype_value)(argument_value)(return_type);

    const signed = sign(prototype_value);

    _ = signed(argument_value)(return_type);
}
