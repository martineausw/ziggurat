///! *sign* function.
const Prototype = @import("prototype/Prototype.zig");

/// Intended to be called at return type of a function signature.
///
/// Calls prototype's *eval* in comptime which must evaluate to *true* to continue.
///
/// Calls prototype's *onFail* in comptime when its *eval* returns *false*.
///
/// Calls prototype's *onError* in comptime when its *eval* returns an error.
pub inline fn sign(prototype: Prototype) fn (actual: anytype) fn (comptime return_type: type) type {
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
                @compileError(prototype.name ++ "." ++ @errorName(err));
            }

            comptime return struct {
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
