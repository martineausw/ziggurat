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
                _ = try @call(.always_inline, is_type_value.eval, .{actual});
                _ = @call(.always_inline, has_active_tag.eval, .{@typeInfo(actual)}) catch |err|
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
    try testing.expectEqual(true, init(.{ .bool = true }).eval(bool));
    try testing.expectEqual(true, init(.{ .int = true }).eval(usize));
    try testing.expectEqual(true, init(.{ .int = true }).eval(i128));
    try testing.expectEqual(true, init(.{ .int = true }).eval(u128));
    try testing.expectEqual(true, init(.{ .float = true }).eval(f128));
    try testing.expectEqual(true, init(.{ .comptime_int = true }).eval(comptime_int));
    try testing.expectEqual(true, init(.{ .comptime_float = true }).eval(comptime_float));
    try testing.expectEqual(true, init(.{ .@"struct" = true }).eval(struct {}));
    try testing.expectEqual(true, init(.{ .@"union" = true }).eval(union {}));
    try testing.expectEqual(true, init(.{ .@"enum" = true }).eval(enum {}));
    try testing.expectEqual(true, init(.{ .error_set = true }).eval(error{}));
    try testing.expectEqual(true, init(.{ .array = true }).eval([3]usize));
    try testing.expectEqual(true, init(.{ .vector = true }).eval(@Vector(3, f128)));
    try testing.expectEqual(true, init(.{ .@"fn" = true }).eval(fn () void));
    try testing.expectEqual(true, init(.{ .pointer = true }).eval(*const enum {}));
    try testing.expectEqual(true, init(.{ .pointer = true }).eval([]const u8));
    try testing.expectEqual(true, init(.{ .pointer = true }).eval([:0]u8));
    try testing.expectEqual(true, init(.{ .pointer = true }).eval([*]struct {}));
}

test "fails has type info" {
    try testing.expectEqual(Error.AssertsInactiveTypeInfo, init(.{ .bool = false }).eval(bool));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(.{ .bool = true }).eval(usize));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsTypeValue, init(.{ .bool = true }).eval(true));
    try testing.expectEqual(Error.AssertsTypeValue, init(.{ .bool = true }).eval(false));
}
