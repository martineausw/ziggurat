const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");
const Type = @import("../Type.zig");
const HasTag = @import("HasTag.zig").Of(std.builtin.Type);

const HasTypeInfoError = error{
    AssertsActiveTypeInfo,
    AssertsInactiveTypeInfo,
};

pub const Error = HasTypeInfoError || Type.Error;
pub const Params = HasTag.Params;

pub fn init(params: HasTag.Params) Prototype {
    const is_type_value = Type.init;
    const has_active_tag = HasTag.init(params);
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try is_type_value.eval(actual);
                _ = has_active_tag.eval(@typeInfo(actual)) catch |err|
                    return switch (err) {
                        HasTag.Error.AssertsActive,
                        => Error.AssertsActiveTypeInfo,
                        HasTag.Error.AssertsInactive,
                        => Error.AssertsInactiveTypeInfo,
                        else => unreachable,
                    };

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
                    Error.AssertsTypeValue => is_type_value.onError.?(err, prototype, actual),

                    Error.AssertsActiveTypeInfo,
                    Error.AssertsInactiveTypeInfo,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: expect: {any}, actual: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params,
                            @tagName(@typeInfo(actual)),
                        },
                    )),
                }
            }
        }.onError,
    };
}

test "has type info" {
    try testing.expectEqual(true, init(.{}).eval(bool));
    try testing.expectEqual(true, init(.{}).eval(usize));
    try testing.expectEqual(true, init(.{}).eval(i128));
    try testing.expectEqual(true, init(.{}).eval(u128));
    try testing.expectEqual(true, init(.{}).eval(f128));
    try testing.expectEqual(true, init(.{}).eval(comptime_int));
    try testing.expectEqual(true, init(.{}).eval(comptime_float));
    try testing.expectEqual(true, init(.{}).eval(struct {}));
    try testing.expectEqual(true, init(.{}).eval(union {}));
    try testing.expectEqual(true, init(.{}).eval(enum {}));
    try testing.expectEqual(true, init(.{}).eval(error{}));
    try testing.expectEqual(true, init(.{}).eval([3]usize));
    try testing.expectEqual(true, init(.{}).eval(@Vector(3, f128)));
    try testing.expectEqual(true, init(.{}).eval(fn () void));
    try testing.expectEqual(true, init(.{}).eval(*const enum {}));
    try testing.expectEqual(true, init(.{}).eval([]const u8));
    try testing.expectEqual(true, init(.{}).eval([:0]u8));
    try testing.expectEqual(true, init(.{}).eval([*]struct {}));
}
