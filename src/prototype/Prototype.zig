//! Validates an argument intended to be used by `Sign`
//! at function return value or tests

/// Name to be used for messages
name: [:0]const u8,
/// Evaluates value, returns an error or false on failure conditions
eval: *const fn (actual: anytype) anyerror!bool,
/// Callback triggered by `Sign` when `eval` returns an error
onError: ?*const fn (err: anyerror, prototype: @This(), actual: anytype) void = null,
/// Callback triggered by `Sign` when `eval` returns false
onFail: ?*const fn (prototype: @This(), actual: anytype) void = null,

const std = @import("std");
const testing = std.testing;

test {
    const runtime_int: @This() = .{
        .name = "RuntimeInt",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    };

    const boolean: @This() = .{
        .name = "bool",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .bool => true,
                    else => false,
                };
            }
        }.eval,
    };

    try testing.expect(true == try runtime_int.eval(@as(u32, 0)));
    try testing.expect(false == try runtime_int.eval(@as(bool, false)));

    try testing.expect(false == try boolean.eval(@as(u32, 0)));
    try testing.expect(true == try boolean.eval(@as(bool, false)));
}

test {
    testing.refAllDecls(@This());
}
