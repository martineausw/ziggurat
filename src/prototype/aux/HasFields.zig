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
                _ = try has_type_info.eval(actual);

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

    try testing.expectEqual(true, try init(&.{
        .{ .name = "a", .type = .is_type },
        .{ .name = "b", .type = .is_bool },
        .{ .name = "x", .type = .is_int(.{}) },
        .{ .name = "y", .type = .is_float(.{}) },
    }).eval(Foo));

    try testing.expectEqual(true, try init(&.{
        .{ .name = "a", .type = .is_type },
        .{ .name = "b", .type = .is_bool },
        .{ .name = "x", .type = .is_int(.{}) },
        .{ .name = "y", .type = .is_float(.{}) },
    }).eval(Bar));
}
