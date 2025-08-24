const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");
const HasField = @import("HasField.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

pub const Error = HasField.Error || HasTypeInfo.Error;
pub const Params = []const HasField.Params;

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .@"struct" = true,
        .@"union" = true,
    });
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                inline for (params) |param_field| {
                    const field_validator = HasField.init(param_field);
                    _ = try field_validator.eval(actual);
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(
                err: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                switch (err) {
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    Error.AssertsInactiveTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsHasField,
                    Error.AssertsOnTypeField,
                    => {
                        const has_field = HasField.init(params[
                            inline for (params, 0..) |field, i| blk: {
                                const has_field = HasField.init(field);
                                has_field.eval(actual) catch
                                    break :blk i;
                            }
                        ]);

                        has_field.onError.?(
                            try has_field.eval(actual),
                            prototype,
                            actual,
                        );
                    },
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "has fields" {
    const Foo = struct {
        a: type,
        b: bool,
        x: usize,
        y: f128,
    };

    const Bar = union {
        a: type,
        b: bool,
        x: usize,
        y: f128,
    };

    try testing.expectEqual(true, init(&.{
        .{ .name = "a", .type = .is_type },
        .{ .name = "b", .type = .is_bool },
        .{ .name = "x", .type = .is_int(.{}) },
        .{ .name = "y", .type = .is_float(.{}) },
    }).eval(Foo));

    try testing.expectEqual(true, init(&.{
        .{ .name = "a", .type = .is_type },
        .{ .name = "b", .type = .is_bool },
        .{ .name = "x", .type = .is_int(.{}) },
        .{ .name = "y", .type = .is_float(.{}) },
    }).eval(Bar));
}

test "fails has fields" {
    const Foo = struct {
        a: usize,
        b: i128,
    };

    const Bar = union {
        a: usize,
        b: i128,
    };

    try testing.expectEqual(Error.AssertsOnTypeField, init(&.{
        .{ .name = "a", .type = .is_bool },
        .{ .name = "b", .type = .is_bool },
    }).eval(Foo));

    try testing.expectEqual(Error.AssertsOnTypeField, init(&.{
        .{ .name = "a", .type = .is_bool },
        .{ .name = "b", .type = .is_bool },
    }).eval(Bar));

    try testing.expectEqual(Error.AssertsHasField, init(&.{
        .{ .name = "x" },
    }).eval(Foo));

    try testing.expectEqual(Error.AssertsHasField, init(&.{
        .{ .name = "x" },
    }).eval(Bar));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsTypeValue, init(&.{}).eval(@as(struct {}, .{})));

    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(bool));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(usize));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(i128));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(f128));
}
