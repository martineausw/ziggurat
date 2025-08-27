const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");

const WithinInterval = @import("aux/WithinInterval.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");

const Self = @This();

const FloatError = error{
    AssertsTypeValue,
    AssertsActiveTypeInfo,
    AssertsMinBits,
    AssertsMaxBits,
};

pub const Error = FloatError || HasTypeInfo.Error;
pub const Params = struct {
    bits: WithinInterval.Params = .{},
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .float = true,
    });

    const bits = WithinInterval.init(params.bits);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                _ = bits.eval(@typeInfo(actual).float.bits) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin,
                        => Error.AssertsMinBits,
                        WithinInterval.Error.AssertsMax,
                        => Error.AssertsMaxBits,
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
                    Error.AssertsTypeValue,
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsMinBits,
                    Error.AssertsMaxBits,
                    => bits.onError.?(
                        try bits.eval(@typeInfo(actual).float.bits),
                        prototype,
                        @typeInfo(actual).float.bits,
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "is float" {
    try testing.expectEqual(true, init(.{}).eval(f16));
    try testing.expectEqual(true, init(.{}).eval(f32));
    try testing.expectEqual(true, init(.{}).eval(f64));
    try testing.expectEqual(true, init(.{}).eval(f128));
}

test "fails is float" {
    try testing.expectEqual(Error.AssertsMinBits, init(.{ .bits = .{ .min = .{ .uint = 64 } } }).eval(f32));
    try testing.expectEqual(Error.AssertsMaxBits, init(.{ .bits = .{ .max = .{ .uint = 16 } } }).eval(f32));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsTypeValue, init(.{}).eval(@as(f32, 0)));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(.{}).eval(i128));
}
