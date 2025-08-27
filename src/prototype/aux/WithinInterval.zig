const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

const Self = @This();

const WithinIntervalError = error{
    AssertsMin,
    AssertsMax,
};

pub const Error = WithinIntervalError || HasTypeInfo.Error;
const Number = union(enum) { int: i128, uint: u128, float: f128 };
pub const Params = struct {
    min: ?Number = null,
    max: ?Number = null,
    tolerance: ?Number = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .int = true,
        .float = true,
        .comptime_int = true,
        .comptime_float = true,
    });

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(@TypeOf(actual));

                switch (@typeInfo(@TypeOf(actual))) {
                    .comptime_int => {
                        const min = if (params.min) |min|
                            min: switch (min) {
                                inline else => |value| break :min value,
                            }
                        else
                            std.math.minInt(i256);

                        const max = if (params.max) |max|
                            max: switch (max) {
                                inline else => |value| break :max value,
                            }
                        else
                            std.math.maxInt(i256);

                        const tolerance = if (params.tolerance) |tolerance|
                            tolerance: switch (tolerance) {
                                inline else => |value| break :tolerance value,
                            }
                        else
                            0;
                        const value: i256 = @intCast(actual);

                        if (value + tolerance < min) return Error.AssertsMin;
                        if (value - tolerance > max) return Error.AssertsMax;
                    },
                    .int => |info| {
                        const min, const max, const tolerance, const value = vals: switch (info.signedness) {
                            .signed => {
                                const min = if (params.min) |min|
                                    min.int
                                else
                                    std.math.minInt(i128);

                                const max = if (params.max) |max|
                                    max.int
                                else
                                    std.math.maxInt(i128);

                                const tolerance = if (params.tolerance) |tolerance|
                                    tolerance.int
                                else
                                    0;

                                const value: i128 = @intCast(actual);

                                break :vals .{ min, max, tolerance, value };
                            },
                            .unsigned => {
                                const min = if (params.min) |min| min.uint else 0;
                                const max = if (params.max) |max| max.uint else std.math.maxInt(u128);
                                const tolerance = if (params.tolerance) |tolerance| tolerance.uint else 0;
                                const value: u128 = @intCast(actual);
                                break :vals .{ min, max, tolerance, value };
                            },
                        };

                        if (value + tolerance < min) return Error.AssertsMin;
                        if (value - tolerance > max) return Error.AssertsMax;
                    },
                    .comptime_float, .float => {
                        const min = if (params.min) |min|
                            min.float
                        else
                            std.math.floatMin(f128);

                        const max = if (params.max) |max|
                            max.float
                        else
                            std.math.floatMax(f128);

                        const tolerance = if (params.tolerance) |tolerance|
                            tolerance.float
                        else
                            std.math.floatEps(f128);

                        const value: f128 = @floatCast(actual);

                        if (!std.math.approxEqAbs(
                            f128,
                            min,
                            value,
                            tolerance,
                        ) and min > value) {
                            return Error.AssertsMin;
                        }

                        if (!std.math.approxEqAbs(
                            f128,
                            max,
                            value,
                            tolerance,
                        ) and max < value) {
                            return Error.AssertsMax;
                        }
                    },
                    else => unreachable,
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

                    Error.AssertsMin,
                    Error.AssertsMax,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {d}",
                        .{
                            prototype.name,
                            @errorName(err),
                            actual,
                        },
                    )),
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "within interval" {
    try testing.expectEqual(true, init(.{
        .min = .{ .uint = std.math.minInt(usize) },
        .max = .{ .uint = std.math.maxInt(usize) },
        .tolerance = .{ .uint = 0 },
    }).eval(@as(usize, 0)));

    try testing.expectEqual(true, init(.{
        .min = .{ .int = std.math.minInt(i128) },
        .max = .{ .int = std.math.maxInt(i128) },
        .tolerance = .{ .int = 0 },
    }).eval(@as(i128, 0)));

    try testing.expectEqual(true, init(.{
        .min = .{ .float = std.math.floatMin(f128) },
        .max = .{ .float = std.math.floatMax(f128) },
        .tolerance = .{ .float = std.math.floatEps(f128) },
    }).eval(@as(f128, 0)));

    try testing.expectEqual(true, init(.{
        .min = .{ .int = 0 },
        .max = .{ .int = 0 },
        .tolerance = .{ .int = 0 },
    }).eval(@as(comptime_int, 0)));

    try testing.expectEqual(true, init(.{
        .min = .{ .float = 0 },
        .max = .{ .float = 0 },
        .tolerance = .{ .float = 0 },
    }).eval(@as(comptime_float, 0)));
}

test "fails within interval" {
    try testing.expectEqual(Error.AssertsMin, init(.{ .min = .{ .uint = 1 } }).eval(@as(usize, 0)));
    try testing.expectEqual(Error.AssertsMax, init(.{ .max = .{ .int = -1 } }).eval(@as(i128, 0)));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(.{}).eval(usize));
}
