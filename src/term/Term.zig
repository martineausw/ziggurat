name: [:0]const u8,
eval: *const fn (actual: anytype) anyerror!bool,
onError: ?*const fn (err: anyerror, term: @This(), actual: anytype) void = null,
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
