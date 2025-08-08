//! Validates an argument intended to be used by `Sign`
//! at function return value or tests

/// Name to be used for messages
name: [:0]const u8,
/// Evaluates value, returns an error or false on failure conditions
eval: *const fn (actual: anytype) anyerror!bool,
/// Callback triggered by `Sign` when `eval` returns an error
onError: ?*const fn (err: anyerror, term: @This(), actual: anytype) void = null,
/// Callback triggered by `Sign` when `eval` returns false
onFail: ?*const fn (term: @This(), actual: anytype) void = null,

const std = @import("std");
const testing = std.testing;

test {
    const AnyRuntimeInt: @This() = .{
        .name = "AnyRuntimeInt",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    };

    const AnyBool: @This() = .{
        .name = "AnyBool",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(@TypeOf(actual))) {
                    .bool => true,
                    else => false,
                };
            }
        }.eval,
    };

    try testing.expect(true == try AnyRuntimeInt.eval(@as(u32, 0)));
    try testing.expect(false == try AnyRuntimeInt.eval(@as(bool, false)));

    try testing.expect(false == try AnyBool.eval(@as(u32, 0)));
    try testing.expect(true == try AnyBool.eval(@as(bool, false)));
}

test {
    testing.refAllDecls(@This());
}
